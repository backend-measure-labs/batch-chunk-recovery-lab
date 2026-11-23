package lab.core.row;

import java.time.ZonedDateTime;

/** UsageRow 에 감사 필드를 붙여 한 번 더 복사한 행. 저장 단계는 이 목록을 받는다. */
public record AuditedRow(
        Long id,
        String cluster,
        String namespace,
        String podName,
        String gpuUuid,
        Double gpuUtil,
        Double cpuUsage,
        Double memoryBytes,
        long intervalSeconds,
        ZonedDateTime collectedAt,
        ZonedDateTime podCreatedAt,
        ZonedDateTime podStatusAt,
        ZonedDateTime createdAt,
        String createdBy) {

    public static AuditedRow of(UsageRow r, ZonedDateTime createdAt, String createdBy) {
        return new AuditedRow(r.id(), r.cluster(), r.namespace(), r.podName(), r.gpuUuid(),
                r.gpuUtil(), r.cpuUsage(), r.memoryBytes(), r.intervalSeconds(),
                r.collectedAt(), r.podCreatedAt(), r.podStatusAt(), createdAt, createdBy);
    }
}
