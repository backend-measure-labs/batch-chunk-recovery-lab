package lab.core;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import lab.core.prom.BodyByteCounter;
import lab.core.prom.PromResponse;
import lab.core.prom.PromResponse.GenericResult;
import lab.core.prom.PrometheusApi;
import lab.core.row.AuditedRow;
import lab.core.row.UsageRow;

/**
 * 조회 → 행 변환 → 감사 필드 복사. A · B · C 가 같은 이 코드를 쓴다.
 * 한 메서드 안에서 응답 · 행 목록 · 복사 목록을 차례로 만든다(원 코드의 흐름).
 */
@Component
public class Collector {

    private static final Logger log = LoggerFactory.getLogger(Collector.class);

    private final PrometheusApi api;
    private final LabProperties props;
    private final Checkpoints cp;
    private final Clock clock;
    private final RunPhase phase;

    public Collector(PrometheusApi api, LabProperties props, Checkpoints cp, Clock clock, RunPhase phase) {
        this.api = api;
        this.props = props;
        this.cp = cp;
        this.clock = clock;
        this.phase = phase;
    }

    /** [start, end] (epoch 초, 양 끝 포함) 를 조회해 수집 시각 오름차순 행 목록을 돌려준다. */
    public List<AuditedRow> collect(long start, long end) {
        cp.mark("c0", 0);
        UsageQueries.Query[] qs = UsageQueries.all(props);

        phase.set("fetch");
        Map<String, GenericResult> gpu = fetch(qs[0], start, end, true);
        Map<String, GenericResult> cpu = fetch(qs[1], start, end, false);
        Map<String, GenericResult> mem = fetch(qs[2], start, end, false);
        Map<String, GenericResult> status = fetch(qs[3], start, end, false);
        Map<String, GenericResult> created = fetch(qs[4], start, end, false);
        cp.mark("c2", 0);

        phase.set("convert");
        ZoneId zone = clock.getZone();
        List<UsageRow> rows = new ArrayList<>();
        for (GenericResult g : gpu.values()) {
            Map<String, String> m = g.metric();
            String podKey = m.get("namespace") + "/" + m.get("pod");
            Cursor cpuC = new Cursor(cpu.get(podKey));
            Cursor memC = new Cursor(mem.get(podKey));
            Cursor stC = new Cursor(status.get(podKey));
            Cursor crC = new Cursor(created.get(podKey));
            for (Object o : g.values()) {
                List<?> point = (List<?>) o;
                long t = ((Number) point.get(0)).longValue();
                Double gv = Double.valueOf((String) point.get(1));
                String cv = cpuC.exact(t);
                String mv = memC.exact(t);
                long stT = stC.floorTime(t);
                String crV = crC.floor(t);
                rows.add(new UsageRow(null, m.get("cluster"), m.get("namespace"), m.get("pod"), m.get("uuid"),
                        gv,
                        cv == null ? null : Double.valueOf(cv),
                        mv == null ? null : Double.valueOf(mv),
                        60L,
                        Instant.ofEpochSecond(t).atZone(zone),
                        crV == null ? null : Instant.ofEpochSecond((long) Double.parseDouble(crV)).atZone(zone),
                        stT < 0 ? null : Instant.ofEpochSecond(stT).atZone(zone)));
            }
        }
        ZonedDateTime now = ZonedDateTime.now(clock);
        List<AuditedRow> audited = new ArrayList<>();
        for (UsageRow r : rows) {
            audited.add(AuditedRow.of(r, now, "gpu-usage-collector"));
        }
        audited.sort(Comparator.comparing(AuditedRow::collectedAt));
        cp.mark("c3", audited.size());
        log.info("ROWS start={} end={} rows={}", start, end, audited.size());
        return audited;
    }

    private Map<String, GenericResult> fetch(UsageQueries.Query q, long start, long end, boolean perCard) {
        BodyByteCounter.reset();
        long t = System.currentTimeMillis();
        PromResponse resp = api.queryRange(q.promql(), start, end, q.step());
        long ms = System.currentTimeMillis() - t;
        if (!"success".equals(resp.status())) {
            throw new IllegalStateException("prometheus error " + resp.errorType() + ": " + resp.error());
        }
        Map<String, GenericResult> byKey = new HashMap<>();
        long points = 0;
        for (GenericResult g : resp.data().result()) {
            Map<String, String> m = g.metric();
            String key = m.get("namespace") + "/" + m.get("pod") + (perCard ? "/" + m.get("uuid") : "");
            byKey.put(key, g);
            points += g.values().size();
        }
        log.info("QUERY name={} start={} end={} step={} series={} points={} bytes={} ms={}",
                q.name(), start, end, q.step(), byKey.size(), points, BodyByteCounter.bytes(), ms);
        return byKey;
    }

    /** 시각 오름차순 점 목록을 앞으로만 훑는다. */
    private static final class Cursor {
        private final List<Object> values;
        private int i = 0;

        Cursor(GenericResult r) { this.values = r == null ? List.of() : r.values(); }

        private long time(int idx) { return ((Number) ((List<?>) values.get(idx)).get(0)).longValue(); }

        private String value(int idx) { return (String) ((List<?>) values.get(idx)).get(1); }

        String exact(long t) {
            while (i < values.size() && time(i) < t) i++;
            return i < values.size() && time(i) == t ? value(i) : null;
        }

        /** t 이하에서 가장 늦은 점의 시각, 없으면 -1 */
        long floorTime(long t) {
            while (i + 1 < values.size() && time(i + 1) <= t) i++;
            return !values.isEmpty() && time(i) <= t ? time(i) : -1;
        }

        String floor(long t) {
            long ft = floorTime(t);
            return ft < 0 ? null : value(i);
        }
    }
}
