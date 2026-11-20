package lab.batch;

import org.springframework.batch.repeat.RepeatContext;
import org.springframework.batch.repeat.policy.CompletionPolicySupport;

/** 아이템(수집 시각 묶음)을 쌓다가 행 수 합이 기준 이상이 되면 청크를 끊는다. */
public class RowCountCompletionPolicy extends CompletionPolicySupport {

    private final WindowedGroupReader reader;
    private final int threshold;

    public RowCountCompletionPolicy(WindowedGroupReader reader, int threshold) {
        this.reader = reader;
        this.threshold = threshold;
    }

    @Override
    public RepeatContext start(RepeatContext parent) {
        reader.resetChunk();
        return super.start(parent);
    }

    @Override
    public boolean isComplete(RepeatContext context) {
        return reader.rowsInChunk() >= threshold;
    }
}
