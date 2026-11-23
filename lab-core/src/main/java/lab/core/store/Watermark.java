package lab.core.store;

import java.time.Clock;

import javax.sql.DataSource;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import lab.core.LabProperties;

/** 재개 지점 = max(커밋된 MAX(수집 시각), 마지막 성공 − 5분), 하한 T0 − 7일. */
@Component
public class Watermark {

    private final JdbcTemplate jdbc;
    private final LabProperties props;
    private final Clock clock;

    public Watermark(@Qualifier("sourceDataSource") DataSource ds, LabProperties props, Clock clock) {
        this.jdbc = new JdbcTemplate(ds);
        this.props = props;
        this.clock = clock;
    }

    public long committedMax() {
        Long v = jdbc.queryForObject(
                "select unix_timestamp(max(collected_at)) from gpu_usage where cluster = ?", Long.class, props.getCluster());
        return v == null ? -1 : v;
    }

    public long resumePoint() {
        long now = clock.instant().getEpochSecond();
        long lower = now - props.getLowerBoundDays() * 86400L;
        long committed = committedMax();
        Long lastSuccess = jdbc.query("select unix_timestamp(last_success_at) from collect_status where name = 'gpu-usage'",
                rs -> rs.next() ? rs.getLong(1) : null);
        long candidate = Math.max(committed, lastSuccess == null ? -1 : lastSuccess - 300);
        return Math.max(candidate, lower);
    }

    public void markSuccess() {
        long now = clock.instant().getEpochSecond();
        jdbc.update("insert into collect_status(name, last_success_at) values ('gpu-usage', from_unixtime(?)) "
                + "on duplicate key update last_success_at = from_unixtime(?)", now, now);
    }
}
