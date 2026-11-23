package lab.core;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** 랩 설정. 값은 환경 변수(LAB_*)로 회차마다 바꾼다. */
@ConfigurationProperties("lab")
public class LabProperties {
    /** Prometheus 주소 */
    private String prometheusUrl = "http://localhost:9090";
    /** 수집 대상 클러스터 라벨 값 (1개 고정) */
    private String cluster = "lab-cluster-1";
    /** 시리즈 수 S: 50 · 224 · 448 · 896 */
    private int series = 224;
    /** 값 자릿수 수준: long · short (백필 라벨 dg) */
    private String digits = "long";
    /** 고정 시각 T0 (epoch 초). 앱의 「지금」 */
    private long t0 = 1761955200L;
    /** full(A) · windowed(B) */
    private String mode = "full";
    /** B · C 의 윈도우 크기(시간) */
    private int windowHours = 24;
    /** 재개 지점 하한 (일) */
    private int lowerBoundDays = 7;
    /** 청크 행 수 기준 */
    private int chunkRows = 500;
    /** 측정 모드 체크포인트 */
    private boolean checkpoints = false;
    /** false 면 행 목록 완성(c3) 뒤 저장을 건너뛴다 (② 축소, README 1.4) */
    private boolean save = true;
    /** 체크포인트 · 히스토그램 출력 디렉터리 */
    private String outDir = "./out";

    public String getPrometheusUrl() { return prometheusUrl; }
    public void setPrometheusUrl(String v) { prometheusUrl = v; }
    public String getCluster() { return cluster; }
    public void setCluster(String v) { cluster = v; }
    public int getSeries() { return series; }
    public void setSeries(int v) { series = v; }
    public String getDigits() { return digits; }
    public void setDigits(String v) { digits = v; }
    public long getT0() { return t0; }
    public void setT0(long v) { t0 = v; }
    public String getMode() { return mode; }
    public void setMode(String v) { mode = v; }
    public int getWindowHours() { return windowHours; }
    public void setWindowHours(int v) { windowHours = v; }
    public int getLowerBoundDays() { return lowerBoundDays; }
    public void setLowerBoundDays(int v) { lowerBoundDays = v; }
    public int getChunkRows() { return chunkRows; }
    public void setChunkRows(int v) { chunkRows = v; }
    public boolean isCheckpoints() { return checkpoints; }
    public void setCheckpoints(boolean v) { checkpoints = v; }
    public boolean isSave() { return save; }
    public void setSave(boolean v) { save = v; }
    public String getOutDir() { return outDir; }
    public void setOutDir(String v) { outDir = v; }
}
