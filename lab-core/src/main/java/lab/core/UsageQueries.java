package lab.core;

/** 쿼리 다섯. 시리즈 수 S 는 그룹 라벨 grp 로 부분집합을 고른다 (백필 한 번으로 50 · 224 · 448 · 896). */
public final class UsageQueries {

    public record Query(String name, String promql, String step) { }

    private UsageQueries() { }

    static String groups(int series) {
        return switch (series) {
            case 50 -> "a";
            case 224 -> "a|b";
            case 448 -> "a|b|c";
            case 896 -> "a|b|c|d";
            default -> throw new IllegalArgumentException("series must be 50|224|448|896: " + series);
        };
    }

    public static Query[] all(LabProperties p) {
        String sel = "cluster=\"" + p.getCluster() + "\",dg=\"" + p.getDigits() + "\",grp=~\"" + groups(p.getSeries()) + "\"";
        return new Query[]{
                new Query("gpu", "sum by (cluster,namespace,pod,gpu,uuid) (lab_gpu_utilization{" + sel + "})", "60s"),
                new Query("cpu", "sum by (cluster,namespace,pod) (rate(lab_cpu_usage_seconds_total{" + sel + "}[5m]))", "60s"),
                new Query("mem", "sum by (cluster,namespace,pod) (lab_memory_working_set_bytes{" + sel + "})", "60s"),
                new Query("status", "sum by (cluster,namespace,pod) (lab_pod_status_ready{" + sel + "})", "600s"),
                new Query("created", "max by (cluster,namespace,pod) (lab_pod_created{" + sel + "})", "600s"),
        };
    }
}
