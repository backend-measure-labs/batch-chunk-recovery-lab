package lab.core.row;

import java.time.ZonedDateTime;

/**
 * (파드, 카드, 수집 시각)마다 하나. 필드 구성은 원 행 클래스의 타입 구성을 따른다:
 * 식별자 · 문자열 4 · 값 객체 3 · long 1 · ZonedDateTime 3.
 */
public record UsageRow(
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
        ZonedDateTime podStatusAt) {
}
