package lab.core;

import java.time.Clock;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import lab.core.row.AuditedRow;
import lab.core.store.ChunkSaver;
import lab.core.store.Watermark;

/**
 * A(full): 재개 지점~지금을 한 번 조회해 힙에 행 목록 하나를 만든 뒤 청크 저장.
 * B(windowed): 같은 일을 시간 윈도우마다. 윈도우마다 커밋된 MAX(수집 시각)가 다음 윈도우의 시작.
 */
@Service
public class CollectService {

    private static final Logger log = LoggerFactory.getLogger(CollectService.class);

    private final LabProperties props;
    private final Collector collector;
    private final ChunkSaver saver;
    private final Watermark watermark;
    private final Checkpoints cp;
    private final Clock clock;
    private final RunPhase phase;

    public CollectService(LabProperties props, Collector collector, ChunkSaver saver, Watermark watermark,
                          Checkpoints cp, Clock clock, RunPhase phase) {
        this.props = props;
        this.collector = collector;
        this.saver = saver;
        this.watermark = watermark;
        this.cp = cp;
        this.clock = clock;
        this.phase = phase;
    }

    @Transactional(propagation = Propagation.NEVER, transactionManager = "sourceTransactionManager")
    public void run() {
        long t = System.currentTimeMillis();
        long now = clock.instant().getEpochSecond();
        long start = watermark.resumePoint();
        log.info("RUN_START mode={} window_h={} series={} digits={} start={} end={}",
                props.getMode(), props.getWindowHours(), props.getSeries(), props.getDigits(), start, now);
        saver.resetCounter();
        long rows = 0;
        int chunks = 0;
        try {
            if ("windowed".equals(props.getMode())) {
                long window = props.getWindowHours() * 3600L;
                long ws = start;
                int w = 0;
                while (ws < now) {
                    long we = Math.min(ws + window, now);
                    cp.window(++w);
                    log.info("WINDOW_START no={} start={} end={}", w, ws, we);
                    List<AuditedRow> list = collector.collect(ws, we);
                    phase.set("save");
                    rows += list.size();
                    chunks += saver.saveAll(list);
                    list = null;
                    long committed = watermark.committedMax();
                    log.info("WINDOW_END no={} committedMax={}", w, committed);
                    ws = Math.max(committed, we);
                }
                cp.mark("final", 0);
            } else {
                cp.window(1);
                List<AuditedRow> list = collector.collect(start, now);
                phase.set("save");
                rows = list.size();
                if (!props.isSave()) {
                    log.info("RUN_END status=list_complete rows={} ms={}", rows, System.currentTimeMillis() - t);
                    phase.set("idle");
                    return;
                }
                chunks = saver.saveAll(list);
            }
            watermark.markSuccess();
            phase.set("idle");
            log.info("RUN_END status=ok rows={} chunks={} ms={}", rows, chunks, System.currentTimeMillis() - t);
        } catch (Throwable e) {
            log.error("RUN_END status=error phase={} error={} ms={}", phase.get(), e.toString(),
                    System.currentTimeMillis() - t, e);
            phase.set("idle");
            throw e;
        }
    }
}
