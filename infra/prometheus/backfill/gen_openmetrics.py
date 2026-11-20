#!/usr/bin/env python3
"""GPU 사용량 수집 배치가 읽는 다섯 메트릭을 OpenMetrics 텍스트로 만든다.

시리즈 = (파드, 카드). 파드마다 카드 1장이라 파드 수 = 시리즈 수.
- dg="long": 896 시리즈(그룹 a 0-49 · b 50-223 · c 224-447 · d 448-895), 게이지 값이 긴 소수("87.33333333333333" 꼴)
- dg="short": 224 시리즈(a · b), 게이지 값이 두 자리 정수("87" 꼴)
분당 메트릭(GPU 비율 · CPU 카운터 · 메모리)은 60초, 10분 쿼리용(파드 상태 · 생성 시각)은 120초 간격.
값은 (시리즈 번호, 분 번호)로 정해지는 결정적 값이라 다시 만들어도 같다.

사용: gen_openmetrics.py --start <epoch> --end <epoch> --out <file>   ([start, end) 구간, end 가 T0 이면 T0 포함)
"""
import argparse
import hashlib

CLUSTER = "lab-cluster-1"


def group(i):
    return "a" if i < 50 else "b" if i < 224 else "c" if i < 448 else "d"


def series():
    for dg, n in (("long", 896), ("short", 224)):
        for i in range(n):
            h = hashlib.md5(f"{i}".encode()).hexdigest()
            pod = f"gpu-train-{i:04d}-worker-0-6d5f8b7c9-{h[:5]}"  # 39자
            uuid = f"GPU-{h[0:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:32]}"
            ns = f"team-ml-{i % 8}"
            yield dg, i, ns, pod, uuid, group(i)


def gauge(dg, i, k, a, b):
    if dg == "short":
        return str((i * a + k * b) % 100)
    return repr(((i * a * 7919 + k * b * 104729) % 999983) / 9999.83 + 0.0000001)


def cpu_counter(dg, i, k):
    if dg == "short":
        return str(30 * k)
    return repr(30 * k + ((i * 13 + k * 7) % 997) / 997)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--start", type=int, required=True)
    ap.add_argument("--end", type=int, required=True)
    ap.add_argument("--t0", type=int, required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    last = a.end if a.end == a.t0 else a.end - 1
    minutes = range(a.start, last + 1, 60)
    twomin = range(a.start - a.start % 120, last + 1, 120)
    twomin = [t for t in twomin if t >= a.start]
    ss = list(series())
    with open(a.out, "w", buffering=8 << 20) as f:
        def family(name, typ, sample_name, label_fn, times, value_fn):
            f.write(f"# TYPE {name} {typ}\n")
            for dg, i, ns, pod, uuid, grp in ss:
                prefix = f'{sample_name}{{cluster="{CLUSTER}",namespace="{ns}",pod="{pod}",{label_fn(uuid)}grp="{grp}",dg="{dg}"}} '
                f.write("".join(f"{prefix}{value_fn(dg, i, t // 60)} {t}\n" for t in times))

        family("lab_gpu_utilization", "gauge", "lab_gpu_utilization",
               lambda u: f'gpu="0",uuid="{u}",', minutes, lambda dg, i, k: gauge(dg, i, k, 3, 5))
        family("lab_cpu_usage_seconds", "counter", "lab_cpu_usage_seconds_total",
               lambda u: "", minutes, cpu_counter)
        family("lab_memory_working_set_bytes", "gauge", "lab_memory_working_set_bytes",
               lambda u: "", minutes, lambda dg, i, k: gauge(dg, i, k, 7, 11))
        family("lab_pod_status_ready", "gauge", "lab_pod_status_ready",
               lambda u: 'condition="true",', twomin, lambda dg, i, k: "1")
        family("lab_pod_created", "gauge", "lab_pod_created",
               lambda u: "", twomin, lambda dg, i, k: str(a.t0 - 10 * 86400 + i * 60))
        f.write("# EOF\n")


if __name__ == "__main__":
    main()
