<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once 'db_connect.php';

// Terima input baik via JSON payload maupun Form POST
$input = json_decode(file_get_contents("php://input"), true);
$category_id = isset($input['food_category_id']) ? intval($input['food_category_id']) : (isset($_POST['food_category_id']) ? intval($_POST['food_category_id']) : 0);
$tenant_id = isset($input['tenant_id']) ? intval($input['tenant_id']) : (isset($_POST['tenant_id']) ? intval($_POST['tenant_id']) : 0);

if ($category_id <= 0 || $tenant_id <= 0) {
    echo json_encode([
        "success" => false,
        "message" => "Parameter food_category_id dan tenant_id wajib diisi"
    ]);
    exit;
}

// 1. Lepaskan relasi kategori di tabel foods agar menu tidak error
$updateFoods = $conn->prepare("UPDATE foods SET food_category_id = NULL WHERE food_category_id = ? AND tenant_id = ?");
if ($updateFoods) {
    $updateFoods->bind_param("ii", $category_id, $tenant_id);
    $updateFoods->execute();
    $updateFoods->close();
}

// 2. Hapus kategori dari tabel food_categories
$stmt = $conn->prepare("DELETE FROM food_categories WHERE food_category_id = ? AND tenant_id = ?");
if (!$stmt) {
    echo json_encode([
        "success" => false,
        "message" => "Gagal menyiapkan query: " . $conn->error
    ]);
    exit;
}

$stmt->bind_param("ii", $category_id, $tenant_id);

if ($stmt->execute()) {
    if ($stmt->affected_rows > 0) {
        echo json_encode([
            "success" => true,
            "message" => "Kategori berhasil dihapus"
        ]);
    } else {
        echo json_encode([
            "success" => false,
            "message" => "Kategori tidak ditemukan atau sudah dihapus"
        ]);
    }
} else {
    echo json_encode([
        "success" => false,
        "message" => "Gagal menghapus kategori: " . $stmt->error
    ]);
}

$stmt->close();
$conn->close();
?>
