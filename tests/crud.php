<?php
// Kiểm tra CRUD + quyền tối thiểu qua PDO dblib (FreeTDS) — cùng driver Laravel dùng khi có pdo_dblib.
// Dùng: php crud.php <freetds-section> <password>
[$_, $server, $pw] = $argv + [null, 'factory', ''];

$pass = 0; $fail = 0;
function check(string $name, bool $ok, string $detail = ''): void {
    global $pass, $fail;
    $ok ? $pass++ : $fail++;
    printf("  [%s] %s%s\n", $ok ? 'PASS' : 'FAIL', $name, $detail !== '' ? " — $detail" : '');
}
function denied(PDO $db, string $sql): array {
    try { $db->exec($sql); return [false, 'KHÔNG bị chặn']; }
    catch (PDOException $e) { return [true, trim(preg_replace('/\s+/', ' ', $e->getMessage()))]; }
}

try {
    $db = new PDO("dblib:host=$server;dbname=FactoryDB;charset=UTF-8", 'ors_integration', $pw, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_TIMEOUT => 10,
        PDO::ATTR_DEFAULT_STR_PARAM => PDO::PARAM_STR_NATL,   // gửi chuỗi dạng N'...' để không mất dấu tiếng Việt
    ]);
} catch (PDOException $e) {
    check("Kết nối ($server)", false, $e->getMessage());
    exit(1);
}
$ver = $db->query("SELECT CAST(SERVERPROPERTY('ProductVersion') AS varchar(20)) + ' ' + CAST(SERVERPROPERTY('ProductLevel') AS varchar(10)) + ' ' + CAST(SERVERPROPERTY('Edition') AS varchar(40))")->fetchColumn();
check("Kết nối ($server)", true, $ver);

$code = 'ORS-' . bin2hex(random_bytes(4));
$name = 'Thép tấm Đà Nẵng — ưu tiên';

// CREATE
$st = $db->prepare('INSERT INTO dbo.ProductionOrder (OrderCode, ProductName, Qty) OUTPUT INSERTED.Id VALUES (?, ?, ?)');
$st->execute([$code, $name, 10]);
$id = (int) $st->fetchColumn();
check('INSERT', $id > 0, "Id=$id");

// READ (kiểm tra tiếng Việt khứ hồi)
$row = $db->query("SELECT ProductName, Qty FROM dbo.ProductionOrder WHERE Id = $id")->fetch(PDO::FETCH_ASSOC);
check('SELECT + Unicode tiếng Việt', $row && $row['ProductName'] === $name, $row['ProductName'] ?? 'không có dòng');

// UPDATE
$n = $db->prepare('UPDATE dbo.ProductionOrder SET Qty = ?, Status = ?, UpdatedAt = GETDATE() WHERE Id = ?');
$n->execute([25, 'DONE', $id]);
check('UPDATE', $n->rowCount() === 1, 'rows=' . $n->rowCount());

// Transaction + ROLLBACK
$db->beginTransaction();
$db->exec("UPDATE dbo.ProductionOrder SET Qty = 999 WHERE Id = $id");
$db->rollBack();
$qty = (int) $db->query("SELECT Qty FROM dbo.ProductionOrder WHERE Id = $id")->fetchColumn();
check('Transaction ROLLBACK giữ nguyên dữ liệu', $qty === 25, "Qty=$qty");

// DELETE
$d = $db->prepare('DELETE FROM dbo.ProductionOrder WHERE Id = ?');
$d->execute([$id]);
check('DELETE', $d->rowCount() === 1, 'rows=' . $d->rowCount());

// Quyền tối thiểu: các thao tác phải bị từ chối
foreach ([
    'Đọc bảng không được cấp (dbo.Recipe)' => 'SELECT * FROM dbo.Recipe',
    'Tạo bảng'                             => 'CREATE TABLE dbo.Hack (Id int)',
    'Xoá bảng (DROP)'                      => 'DROP TABLE dbo.ProductionOrder',
    'Sửa cấu trúc bảng (ALTER)'            => 'ALTER TABLE dbo.ProductionOrder ADD X int',
    'TRUNCATE'                             => 'TRUNCATE TABLE dbo.ProductionOrder',
    'Tạo login mới'                        => "CREATE LOGIN hack WITH PASSWORD = 'Hack#12345678'",
] as $label => $sql) {
    [$ok, $msg] = denied($db, $sql);
    check("Bị chặn: $label", $ok, mb_strimwidth($msg, 0, 110, '…'));
}

printf("  => %d PASS, %d FAIL\n", $pass, $fail);
exit($fail ? 1 : 0);
