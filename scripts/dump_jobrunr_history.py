#!/usr/bin/env python3
"""JobRunr 잡 JSON(한 줄에 하나)의 상태 이력을 CSV 로 낸다: job_id,state,at,reason"""
import json
import sys

print("job_id,state,at,reason")
for line in open(sys.argv[1], encoding="utf-8"):
    line = line.strip()
    if not line:
        continue
    # mysql -B 출력은 \\ · \n 을 이스케이프한다
    line = line.replace("\\\\", "\\")
    try:
        job = json.loads(line)
    except json.JSONDecodeError:
        continue
    for h in job.get("jobHistory", []):
        state = h.get("state", "")
        at = h.get("createdAt", "")
        reason = " | ".join(str(x) for x in (h.get("message"), h.get("exceptionType"), h.get("exceptionMessage")) if x)
        reason = str(reason).replace(",", ";").replace("\n", " ")[:160]
        print(f"{job.get('id')},{state},{at},{reason}")
