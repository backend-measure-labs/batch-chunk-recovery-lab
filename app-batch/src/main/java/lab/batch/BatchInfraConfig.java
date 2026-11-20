package lab.batch;

import javax.sql.DataSource;

import org.springframework.batch.core.configuration.support.DefaultBatchConfiguration;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Configuration;
import org.springframework.transaction.PlatformTransactionManager;

/**
 * JobRepository 를 원천 데이터소스 · 원천 트랜잭션 매니저에 둔다.
 * 청크 데이터 커밋과 ExecutionContext 갱신이 한 트랜잭션이 되게 하는 Spring Batch 권장 구성.
 */
@Configuration
public class BatchInfraConfig extends DefaultBatchConfiguration {

    private final DataSource sourceDataSource;
    private final PlatformTransactionManager sourceTm;

    public BatchInfraConfig(@Qualifier("sourceDataSource") DataSource sourceDataSource,
                            @Qualifier("sourceTransactionManager") PlatformTransactionManager sourceTm) {
        this.sourceDataSource = sourceDataSource;
        this.sourceTm = sourceTm;
    }

    @Override
    protected DataSource getDataSource() { return sourceDataSource; }

    @Override
    protected PlatformTransactionManager getTransactionManager() { return sourceTm; }
}
