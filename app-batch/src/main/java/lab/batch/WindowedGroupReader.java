package lab.batch;

import java.time.Clock;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.batch.item.ExecutionContext;
import org.springframework.batch.item.ItemStreamReader;

import lab.core.Checkpoints;
import lab.core.Collector;
import lab.core.LabProperties;
import lab.core.RunPhase;
import lab.core.row.AuditedRow;
import lab.core.store.Watermark;

/**
 * B 와 같은 윈도우 단위로 읽는다. 아이템 = 수집 시각 하나의 행 묶음.
 * 재시작 위치는 ExecutionContext 의 마지막 커밋된 청크의 마지막 수집 시각.
 * 윈도우 조회는 양 끝을 포함하므로, 앞 윈도우에서 이미 내보낸 경계 시각은 다음 윈도우에서 다시 내보내지 않는다.
 * 재시작 직후 첫 윈도우의 시작 시각은 이 실행에서 처음 내보내는 것이라 다시 넣는다(A · B 와 같은 DELETE 후 INSERT).
 */
public class WindowedGroupReader implements ItemStreamReader<List<AuditedRow>> {

    static final String KEY = "reader.resumeFrom";
    private static final Logger log = LoggerFactory.getLogger(WindowedGroupReader.class);

    private final Collector collector;
    private final Watermark watermark;
    private final LabProperties props;
    private final Clock clock;
    private final Checkpoints cp;
    private final RunPhase phase;

    private long end;
    private long ws;
    private final Deque<List<AuditedRow>> buffer = new ArrayDeque<>();
    private int windowNo = 0;
    private int groupsInWindow = 0;
    private int groupsEmitted = 0;
    private long lastReadTs = -1;
    private long firstReadTs = -1;
    private long lastBufferedTs = -1;
    private int rowsInChunk = 0;

    public WindowedGroupReader(Collector collector, Watermark watermark, LabProperties props, Clock clock,
                               Checkpoints cp, RunPhase phase) {
        this.collector = collector;
        this.watermark = watermark;
        this.props = props;
        this.clock = clock;
        this.cp = cp;
        this.phase = phase;
    }

    @Override
    public void open(ExecutionContext ctx) {
        end = clock.instant().getEpochSecond();
        if (ctx.containsKey(KEY)) {
            ws = ctx.getLong(KEY);
            log.info("READER_OPEN restart=true start={} end={}", ws, end);
        } else {
            ws = watermark.resumePoint();
            log.info("READER_OPEN restart=false start={} end={}", ws, end);
        }
        log.info("RUN_START mode=batch window_h={} series={} digits={} start={} end={}",
                props.getWindowHours(), props.getSeries(), props.getDigits(), ws, end);
    }

    @Override
    public List<AuditedRow> read() {
        while (buffer.isEmpty()) {
            if (ws >= end) {
                return null;
            }
            long we = Math.min(ws + props.getWindowHours() * 3600L, end);
            cp.window(++windowNo);
            log.info("WINDOW_START no={} start={} end={}", windowNo, ws, we);
            List<AuditedRow> rows = collector.collect(ws, we);
            phase.set("save");
            int from = 0;
            for (int i = 1; i <= rows.size(); i++) {
                if (i == rows.size() || !rows.get(i).collectedAt().equals(rows.get(from).collectedAt())) {
                    long ts = rows.get(from).collectedAt().toEpochSecond();
                    if (ts > lastBufferedTs) {
                        buffer.add(rows.subList(from, i));
                        lastBufferedTs = ts;
                    }
                    from = i;
                }
            }
            groupsInWindow = buffer.size();
            groupsEmitted = 0;
            ws = we;
        }
        List<AuditedRow> g = buffer.poll();
        groupsEmitted++;
        if (groupsEmitted == groupsInWindow / 2) {
            cp.mark("c4", groupsInWindow);
        }
        lastReadTs = g.get(0).collectedAt().toEpochSecond();
        if (rowsInChunk == 0) firstReadTs = lastReadTs;
        rowsInChunk += g.size();
        return g;
    }

    @Override
    public void update(ExecutionContext ctx) {
        if (lastReadTs >= 0) {
            ctx.putLong(KEY, lastReadTs);
        }
    }

    @Override
    public void close() {
        buffer.clear();
    }

    int rowsInChunk() { return rowsInChunk; }

    long firstReadTs() { return firstReadTs; }

    long lastReadTs() { return lastReadTs; }

    void resetChunk() { rowsInChunk = 0; }
}
