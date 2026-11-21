package lab.batch;

import java.time.Clock;
import java.util.ArrayList;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.batch.core.ChunkListener;
import org.springframework.batch.core.Job;
import org.springframework.batch.core.JobExecution;
import org.springframework.batch.core.JobExecutionListener;
import org.springframework.batch.core.Step;
import org.springframework.batch.core.configuration.annotation.StepScope;
import org.springframework.batch.core.job.builder.JobBuilder;
import org.springframework.batch.core.repository.JobRepository;
import org.springframework.batch.core.scope.context.ChunkContext;
import org.springframework.batch.core.step.builder.StepBuilder;
import org.springframework.batch.item.ItemWriter;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.transaction.PlatformTransactionManager;

import lab.core.Checkpoints;
import lab.core.Collector;
import lab.core.LabProperties;
import lab.core.RunPhase;
import lab.core.row.AuditedRow;
import lab.core.store.ChunkStore;
import lab.core.store.Watermark;

@Configuration
public class BatchJobConfig {

    static final String JOB = "gpuUsageCollectJob";
    private static final Logger log = LoggerFactory.getLogger(BatchJobConfig.class);

    @Bean
    @StepScope
    public WindowedGroupReader windowedGroupReader(Collector collector, Watermark watermark, LabProperties props,
                                                   Clock clock, Checkpoints cp, RunPhase phase) {
        return new WindowedGroupReader(collector, watermark, props, clock, cp, phase);
    }

    @Bean
    public Step collectStep(JobRepository repo,
                            @Qualifier("sourceTransactionManager") PlatformTransactionManager tm,
                            WindowedGroupReader reader, ChunkStore store, LabProperties props) {
        long[] chunkNo = {0};
        ItemWriter<List<AuditedRow>> writer = chunk -> {
            List<AuditedRow> rows = new ArrayList<>();
            for (List<AuditedRow> g : chunk) rows.addAll(g);
            store.deleteAndInsert(rows);
        };
        ChunkListener listener = new ChunkListener() {
            private long t;

            @Override
            public void beforeChunk(ChunkContext context) { t = System.currentTimeMillis(); }

            @Override
            public void afterChunk(ChunkContext context) {
                chunkNo[0]++;
                log.info("CHUNK_COMMIT no={} of=? from={} to={} rows={} interrupted={} ms={}",
                        chunkNo[0], reader.firstReadTs(), reader.lastReadTs(), reader.rowsInChunk(),
                        Thread.currentThread().isInterrupted(), System.currentTimeMillis() - t);
            }

            @Override
            public void afterChunkError(ChunkContext context) {
                log.warn("CHUNK_ERROR no={} from={} to={}", chunkNo[0] + 1, reader.firstReadTs(), reader.lastReadTs());
            }
        };
        return new StepBuilder("collectStep", repo)
                .<List<AuditedRow>, List<AuditedRow>>chunk(new RowCountCompletionPolicy(reader, props.getChunkRows()), tm)
                .reader(reader)
                .writer(writer)
                .listener(listener)
                .build();
    }

    @Bean
    public Job collectJob(JobRepository repo, Step collectStep, Watermark watermark, RunPhase phase) {
        return new JobBuilder(JOB, repo)
                .start(collectStep)
                .listener(new JobExecutionListener() {
                    private long t;

                    @Override
                    public void beforeJob(JobExecution e) { t = System.currentTimeMillis(); }

                    @Override
                    public void afterJob(JobExecution e) {
                        if (e.getStatus() == org.springframework.batch.core.BatchStatus.COMPLETED) {
                            watermark.markSuccess();
                            log.info("RUN_END status=ok ms={}", System.currentTimeMillis() - t);
                        } else {
                            log.error("RUN_END status=error phase={} batchStatus={} error={} ms={}", phase.get(),
                                    e.getStatus(), e.getAllFailureExceptions(), System.currentTimeMillis() - t);
                        }
                        phase.set("idle");
                    }
                })
                .build();
    }
}
