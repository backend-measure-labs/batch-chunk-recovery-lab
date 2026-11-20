package lab.core;

import org.springframework.stereotype.Component;

/** OOME 가 어느 단계에서 났는지 남기기 위한 표지 (fetch · convert · save). */
@Component
public class RunPhase {
    private volatile String phase = "idle";

    public void set(String p) { phase = p; }

    public String get() { return phase; }
}
