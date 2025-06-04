<?php
$file_path = __DIR__ . '/ProtectShield.zip';

// Check if file exists
if (!file_exists($file_path)) {
    http_response_code(404);
    die('File not found: ' . $file_path);
}

// Check if file is readable
if (!is_readable($file_path)) {
    http_response_code(403);
    die('File not readable: ' . $file_path);
}

// Get file size
$file_size = filesize($file_path);

// Set headers for file download
header('Content-Type: application/zip');
header('Content-Disposition: attachment; filename="ProtectShield.zip"');
header('Content-Length: ' . $file_size);
header('Cache-Control: must-revalidate');
header('Pragma: public');

// Output the file
readfile($file_path);
exit;
?> 