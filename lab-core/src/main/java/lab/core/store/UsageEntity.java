package lab.core.store;

import java.time.ZonedDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.SequenceGenerator;
import jakarta.persistence.Table;
import lab.core.row.AuditedRow;

@Entity
@Table(name = "gpu_usage")
public class UsageEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "gpu_usage_seq")
    @SequenceGenerator(name = "gpu_usage_seq", sequenceName = "gpu_usage_seq", allocationSize = 500)
    private Long id;

    private String cluster;
    private String namespace;
    @Column(name = "pod_name")
    private String podName;
    @Column(name = "gpu_uuid")
    private String gpuUuid;
    @Column(name = "gpu_util")
    private Double gpuUtil;
    @Column(name = "cpu_usage")
    private Double cpuUsage;
    @Column(name = "memory_bytes")
    private Double memoryBytes;
    @Column(name = "interval_seconds")
    private long intervalSeconds;
    @Column(name = "collected_at")
    private ZonedDateTime collectedAt;
    @Column(name = "pod_created_at")
    private ZonedDateTime podCreatedAt;
    @Column(name = "pod_status_at")
    private ZonedDateTime podStatusAt;
    @Column(name = "created_at")
    private ZonedDateTime createdAt;
    @Column(name = "created_by")
    private String createdBy;

    protected UsageEntity() { }

    public static UsageEntity from(AuditedRow r) {
        UsageEntity e = new UsageEntity();
        e.cluster = r.cluster();
        e.namespace = r.namespace();
        e.podName = r.podName();
        e.gpuUuid = r.gpuUuid();
        e.gpuUtil = r.gpuUtil();
        e.cpuUsage = r.cpuUsage();
        e.memoryBytes = r.memoryBytes();
        e.intervalSeconds = r.intervalSeconds();
        e.collectedAt = r.collectedAt();
        e.podCreatedAt = r.podCreatedAt();
        e.podStatusAt = r.podStatusAt();
        e.createdAt = r.createdAt();
        e.createdBy = r.createdBy();
        return e;
    }
}
