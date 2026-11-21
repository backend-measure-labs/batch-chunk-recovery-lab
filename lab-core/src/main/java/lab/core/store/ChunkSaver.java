package lab.core.store;

import java.util.ArrayList;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;

import lab.core.Checkpoints;
import lab.core.LabProperties;
import lab.core.row.AuditedRow;

/**
 * A · B 의 저장: 수집 시각 오름차순 목록을 시각을 쪼개지 않고 행 수 합이 500 이상이 되면 끊고,
 * 단위마다 REQUIRES_NEW 트랜잭션으로 DELETE 후 INSERT.
 */
@Component
public class ChunkSaver {

    private static final Logger log = LoggerFactory.getLogger(ChunkSaver.class);

    private final ChunkStore store;
    private final TransactionTemplate tx;
    private final LabProperties props;
    private final Checkpoints cp;
    private long chunkNo = 0;

    public ChunkSaver(ChunkStore store, @Qualifier("sourceTransactionManager") PlatformTransactionManager tm,
                      LabProperties props, Checkpoints cp) {
        this.store = store;
        this.tx = new TransactionTemplate(tm);
        this.tx.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
        this.props = props;
        this.cp = cp;
    }

    public void resetCounter() { chunkNo = 0; }

    /** 끊는 위치(끝 인덱스, 배타) 목록. A · B · C 가 같은 규칙을 쓴다. */
    public static List<Integer> boundaries(List<AuditedRow> sorted, int chunkRows) {
        List<Integer> ends = new ArrayList<>();
        int count = 0;
        for (int i = 0; i < sorted.size(); i++) {
            count++;
            boolean lastOfTime = i + 1 == sorted.size()
                    || !sorted.get(i + 1).collectedAt().equals(sorted.get(i).collectedAt());
            if (lastOfTime && count >= chunkRows) {
                ends.add(i + 1);
                count = 0;
            }
        }
        if (count > 0) ends.add(sorted.size());
        return ends;
    }

    public int saveAll(List<AuditedRow> sorted) {
        List<Integer> ends = boundaries(sorted, props.getChunkRows());
        int from = 0;
        for (int k = 0; k < ends.size(); k++) {
            int to = ends.get(k);
            List<AuditedRow> chunk = sorted.subList(from, to);
            long t = System.currentTimeMillis();
            tx.executeWithoutResult(s -> store.deleteAndInsert(chunk));
            chunkNo++;
            log.info("CHUNK_COMMIT no={} of={} from={} to={} rows={} interrupted={} ms={}",
                    chunkNo, ends.size(), chunk.get(0).collectedAt().toEpochSecond(),
                    chunk.get(chunk.size() - 1).collectedAt().toEpochSecond(), chunk.size(),
                    Thread.currentThread().isInterrupted(), System.currentTimeMillis() - t);
            if (k == ends.size() / 2) {
                cp.mark("c4", sorted.size());
            }
            from = to;
        }
        cp.mark("c5", sorted.size());
        return ends.size();
    }
}
