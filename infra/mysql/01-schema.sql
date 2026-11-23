-- 원천(수집 테이블)과 잡 러너 저장소를 같은 MySQL 의 다른 스키마로 둔다.
CREATE DATABASE IF NOT EXISTS source;
CREATE DATABASE IF NOT EXISTS jobrunr;
CREATE USER IF NOT EXISTS 'lab'@'%' IDENTIFIED BY 'lab';
GRANT ALL ON source.* TO 'lab'@'%';
GRANT ALL ON jobrunr.* TO 'lab'@'%';
GRANT PROCESS ON *.* TO 'lab'@'%';

USE source;

CREATE TABLE gpu_usage (
  id               BIGINT       NOT NULL PRIMARY KEY,
  cluster          VARCHAR(64)  NOT NULL,
  namespace        VARCHAR(64)  NOT NULL,
  pod_name         VARCHAR(128) NOT NULL,
  gpu_uuid         VARCHAR(64)  NOT NULL,
  gpu_util         DOUBLE,
  cpu_usage        DOUBLE,
  memory_bytes     DOUBLE,
  interval_seconds BIGINT       NOT NULL,
  collected_at     DATETIME     NOT NULL,
  pod_created_at   DATETIME,
  pod_status_at    DATETIME,
  created_at       DATETIME,
  created_by       VARCHAR(64),
  KEY idx_cluster_collected (cluster, collected_at)
) ENGINE=InnoDB;

-- @SequenceGenerator(allocationSize=500) 를 MySQL 에서 Hibernate 가 테이블로 흉내 낸다.
CREATE TABLE gpu_usage_seq (next_val BIGINT) ENGINE=InnoDB;
INSERT INTO gpu_usage_seq VALUES (1);

CREATE TABLE collect_status (
  name            VARCHAR(64) NOT NULL PRIMARY KEY,
  last_success_at DATETIME
) ENGINE=InnoDB;
