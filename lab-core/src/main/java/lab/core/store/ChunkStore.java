package lab.core.store;

import java.util.List;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;

import org.springframework.stereotype.Component;

import lab.core.row.AuditedRow;

/** 청크 하나의 쓰기 문장: 그 청크의 시각 범위를 DELETE 한 뒤 INSERT. 트랜잭션은 부르는 쪽이 연다. */
@Component
public class ChunkStore {

    @PersistenceContext(unitName = "source")
    private EntityManager em;

    public void deleteAndInsert(List<AuditedRow> chunk) {
        AuditedRow first = chunk.get(0);
        AuditedRow last = chunk.get(chunk.size() - 1);
        em.createQuery("delete from UsageEntity u where u.cluster = :c and u.collectedAt between :a and :b")
                .setParameter("c", first.cluster())
                .setParameter("a", first.collectedAt())
                .setParameter("b", last.collectedAt())
                .executeUpdate();
        for (AuditedRow r : chunk) {
            em.persist(UsageEntity.from(r));
        }
        em.flush();
        em.clear();
    }
}
