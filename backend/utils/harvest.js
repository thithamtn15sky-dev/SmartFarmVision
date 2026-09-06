// Tính các chỉ số xuất chuồng.
//
// Gà thịt lớn rất nhanh (Tam Hoàng 70 ngày, gà siêu thịt còn ngắn hơn), nên lịch
// xuất chuồng phải tính theo NGÀY chứ không theo tháng. Một đàn vào ngày 1/7 thì
// đầu tháng 9 đã tới lứa, chỉ chậm vài ngày là quá lứa, tốn cám mà giá bán giảm.

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/// Số ngày trọn vẹn giữa hai mốc (làm tròn theo ngày, bỏ phần giờ).
function daysBetween(from, to) {
    const a = Date.UTC(from.getFullYear(), from.getMonth(), from.getDate());
    const b = Date.UTC(to.getFullYear(), to.getMonth(), to.getDate());
    return Math.round((b - a) / MS_PER_DAY);
}

/// Suy ra ngày xuất chuồng nếu chuồng chưa lưu sẵn: ngày vào đàn + harvest_days.
function resolveHarvestDate(coop, breed) {
    if (coop.harvest_target_date) return new Date(coop.harvest_target_date);
    if (breed && breed.harvest_days && coop.flock_start_date) {
        const d = new Date(coop.flock_start_date);
        d.setDate(d.getDate() + breed.harvest_days);
        return d;
    }
    return null;
}

/// Gom toàn bộ chỉ số xuất chuồng của một chuồng.
function computeHarvestInfo(coop, breed) {
    const now = new Date();

    // Chuồng tạo trước khi có 2 trường này thì lấy tạm theo quantity.
    const initial = coop.initial_quantity ?? coop.quantity ?? 0;
    const current = coop.current_quantity ?? coop.quantity ?? 0;
    const lost = Math.max(0, initial - current);

    // Tỷ lệ xuất chuồng = tỷ lệ sống = còn sống / ban đầu x 100.
    const harvestRate = initial > 0 ? (current / initial) * 100 : 0;

    const ageDays = coop.flock_start_date
        ? Math.max(0, daysBetween(new Date(coop.flock_start_date), now))
        : null;

    const harvestDate = resolveHarvestDate(coop, breed);
    const daysRemaining = harvestDate ? daysBetween(now, harvestDate) : null;
    const totalDays = breed?.harvest_days
        ?? (harvestDate && coop.flock_start_date
            ? daysBetween(new Date(coop.flock_start_date), harvestDate)
            : null);

    // Đã nuôi được bao nhiêu phần trăm chặng đường tới ngày xuất chuồng.
    const growthPercent = totalDays && totalDays > 0 && ageDays !== null
        ? Math.min(100, Math.round((ageDays / totalDays) * 100))
        : null;

    let harvestStatus = 'UNKNOWN';
    let harvestLabel = 'Chưa gán giống nên chưa tính được ngày xuất chuồng';
    if (daysRemaining !== null) {
        if (coop.status === 'HARVESTED' || coop.status === 'SOLD') {
            harvestStatus = 'DONE';
            harvestLabel = coop.harvested_at
                ? `Đã xuất chuồng ngày ${new Date(coop.harvested_at).toLocaleDateString('vi-VN')}`
                : 'Đàn đã xuất chuồng';
        } else if (daysRemaining < 0) {
            harvestStatus = 'OVERDUE';
            harvestLabel = `Quá lứa ${Math.abs(daysRemaining)} ngày - nên xuất gấp, để lâu tốn cám và giảm giá bán`;
        } else if (daysRemaining === 0) {
            harvestStatus = 'READY';
            harvestLabel = 'Đến lứa xuất chuồng hôm nay';
        } else if (daysRemaining <= 7) {
            harvestStatus = 'SOON';
            harvestLabel = `Còn ${daysRemaining} ngày là tới lứa - chuẩn bị đầu ra và ngừng thuốc đúng thời gian cách ly`;
        } else {
            harvestStatus = 'GROWING';
            harvestLabel = `Còn ${daysRemaining} ngày nữa tới lứa xuất chuồng`;
        }
    }

    // Chuồng đã xuất thì trạng thái là DONE dù chưa gán giống.
    if ((coop.status === 'HARVESTED' || coop.status === 'SOLD') && harvestStatus === 'UNKNOWN') {
        harvestStatus = 'DONE';
        harvestLabel = coop.harvested_at
            ? `Đã xuất chuồng ngày ${new Date(coop.harvested_at).toLocaleDateString('vi-VN')}`
            : 'Đàn đã xuất chuồng';
    }

    return {
        breed_id: coop.breed_id || null,
        harvested_at: coop.harvested_at || null,
        breed_name: breed ? breed.ten_giong : null,
        initial_quantity: initial,
        current_quantity: current,
        lost_quantity: lost,
        harvest_rate: Math.round(harvestRate * 10) / 10,
        age_days: ageDays,
        total_grow_days: totalDays,
        growth_percent: growthPercent,
        harvest_target_date: harvestDate,
        days_remaining: daysRemaining,
        harvest_status: harvestStatus,
        harvest_label: harvestLabel,
        expected_weight_kg: breed ? breed.trong_luong_xuat_chuong_kg : null,
        // Tổng khối lượng ước tính khi xuất, dùng để người nuôi ước doanh thu.
        expected_total_kg: breed && breed.trong_luong_xuat_chuong_kg
            ? Math.round(current * breed.trong_luong_xuat_chuong_kg)
            : null,
    };
}

module.exports = { computeHarvestInfo, daysBetween };
