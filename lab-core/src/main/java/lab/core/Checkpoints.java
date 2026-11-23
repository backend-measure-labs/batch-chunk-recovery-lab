package lab.core;

import java.io.IOException;
import java.lang.management.ManagementFactory;
import java.lang.management.MemoryUsage;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;

import javax.management.MBeanServer;
import javax.management.ObjectName;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * 측정 모드 전용. System.gc() 직후 힙 사용량(= 라이브셋)과 클래스 히스토그램을 남긴다.
 * 상한 모드에서는 꺼져 있다(강제 GC 가 OOM 판정을 바꾸므로).
 */
@Component
public class Checkpoints {

    private static final Logger log = LoggerFactory.getLogger(Checkpoints.class);

    private final LabProperties props;
    private int window = 0;
    private int lastWindowWithHistogram = -1;

    public Checkpoints(LabProperties props) { this.props = props; }

    public boolean enabled() { return props.isCheckpoints(); }

    public void window(int w) { this.window = w; }

    public int window() { return window; }

    /** 히스토그램은 윈도우 1 과 마지막으로 표시된 윈도우에서만 남긴다(1시간 윈도우면 168개라서). */
    public void mark(String name, long rows) {
        if (!props.isCheckpoints()) return;
        try {
            System.gc();
            MemoryUsage h = ManagementFactory.getMemoryMXBean().getHeapMemoryUsage();
            Path dir = Path.of(props.getOutDir());
            Files.createDirectories(dir);
            Path csv = dir.resolve("checkpoints.csv");
            if (!Files.exists(csv)) {
                Files.writeString(csv, "epoch_ms,window,point,rows,heap_used,heap_committed\n");
            }
            Files.writeString(csv, System.currentTimeMillis() + "," + window + "," + name + "," + rows + ","
                    + h.getUsed() + "," + h.getCommitted() + "\n", StandardOpenOption.APPEND);
            log.info("CHECKPOINT window={} point={} rows={} heapUsed={} heapCommitted={}",
                    window, name, rows, h.getUsed(), h.getCommitted());
            if (window <= 1 || name.startsWith("final")) {
                writeHistogram(dir.resolve("histogram-" + name + "-w" + window + ".txt"));
            }
        } catch (Exception e) {
            log.warn("CHECKPOINT_FAILED point={} error={}", name, e.toString());
        }
    }

    private void writeHistogram(Path out) throws Exception {
        MBeanServer server = ManagementFactory.getPlatformMBeanServer();
        ObjectName dcmd = new ObjectName("com.sun.management:type=DiagnosticCommand");
        String text = (String) server.invoke(dcmd, "gcClassHistogram",
                new Object[]{new String[0]}, new String[]{String[].class.getName()});
        Files.writeString(out, text);
    }
}
