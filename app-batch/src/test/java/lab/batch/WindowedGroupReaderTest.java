package lab.batch;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.batch.item.ExecutionContext;

import lab.core.Checkpoints;
import lab.core.Collector;
import lab.core.LabProperties;
import lab.core.RunPhase;
import lab.core.row.AuditedRow;
import lab.core.store.Watermark;

/** 창 조회가 양 끝을 포함해도 경계 시각을 한 번만 내보내는지 (batch-chunk-recovery-lab#2). */
class WindowedGroupReaderTest {

    static final long START = 1_794_614_400L;      // T0 − 1일
    static final long END = START + 3 * 3600;      // 1시간 창 3개
    static final int SERIES = 2;

    @Test
    void 창_경계_시각을_한_번만_내보낸다() {
        List<Long> ts = readAll(new ExecutionContext());
        assertThat(ts).doesNotHaveDuplicates();
        assertThat(ts).hasSize(3 * 60 + 1);         // [START, END] 의 분 수
        assertThat(ts.get(0)).isEqualTo(START);
        assertThat(ts.get(ts.size() - 1)).isEqualTo(END);
    }

    @Test
    void 재시작하면_마지막_커밋_시각부터_다시_내보낸다() {
        long resume = START + 90 * 60;
        ExecutionContext ctx = new ExecutionContext();
        ctx.putLong(WindowedGroupReader.KEY, resume);
        List<Long> ts = readAll(ctx);
        assertThat(ts).doesNotHaveDuplicates();
        assertThat(ts.get(0)).isEqualTo(resume);
        assertThat(ts).hasSize((int) ((END - resume) / 60) + 1);
    }

    private List<Long> readAll(ExecutionContext ctx) {
        LabProperties props = new LabProperties();
        props.setWindowHours(1);
        Collector collector = mock(Collector.class);
        when(collector.collect(anyLong(), anyLong())).thenAnswer(inv -> rows(inv.getArgument(0), inv.getArgument(1)));
        Watermark watermark = mock(Watermark.class);
        when(watermark.resumePoint()).thenReturn(START);
        Clock clock = Clock.fixed(Instant.ofEpochSecond(END), ZoneOffset.UTC);
        WindowedGroupReader reader = new WindowedGroupReader(collector, watermark, props, clock,
                new Checkpoints(props), new RunPhase());
        reader.open(ctx);
        List<Long> out = new ArrayList<>();
        List<AuditedRow> g;
        while ((g = reader.read()) != null) {
            assertThat(g).hasSize(SERIES);
            out.add(g.get(0).collectedAt().toEpochSecond());
        }
        return out;
    }

    /** Collector 계약: [start, end] 양 끝 포함, 수집 시각 오름차순. */
    private static List<AuditedRow> rows(long start, long end) {
        List<AuditedRow> rows = new ArrayList<>();
        for (long t = start; t <= end; t += 60) {
            for (int s = 0; s < SERIES; s++) {
                rows.add(new AuditedRow(null, "c", "ns", "pod-" + s, "uuid-" + s, 1.0, 1.0, 1.0, 60L,
                        Instant.ofEpochSecond(t).atZone(ZoneOffset.UTC), null, null, null, "test"));
            }
        }
        return rows;
    }
}
