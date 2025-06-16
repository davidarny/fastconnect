<?php
// Simple log viewer for FastConnect VPN landing page
// Access this file directly to view logs

$log_dir = __DIR__ . '/logs';
$log_type = $_GET['type'] ?? 'requests';
$date = $_GET['date'] ?? date('Y-m-d');

function get_available_dates($log_dir, $type) {
    $dates = [];
    if (is_dir($log_dir)) {
        $files = glob($log_dir . '/' . $type . '_*.log');
        foreach ($files as $file) {
            if (preg_match('/' . $type . '_(\d{4}-\d{2}-\d{2})\.log$/', basename($file), $matches)) {
                $dates[] = $matches[1];
            }
        }
    }
    rsort($dates);
    return $dates;
}

function format_log_entry($entry) {
    $data = json_decode($entry, true);
    if (!$data) return $entry;
    
    $formatted = "<div class='log-entry'>";
    $formatted .= "<div class='timestamp'>" . ($data['timestamp'] ?? 'Unknown time') . "</div>";
    
    foreach ($data as $key => $value) {
        if ($key === 'timestamp') continue;
        
        // Special handling for response_body field
        if ($key === 'response_body' && $value !== 'empty' && !empty($value)) {
            // Try to decode as JSON and format it
            $json_data = json_decode($value, true);
            if (json_last_error() === JSON_ERROR_NONE && $json_data !== null) {
                $formatted_json = json_encode($json_data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
                $formatted .= "<div class='log-field'><strong>" . ucfirst(str_replace('_', ' ', $key)) . ":</strong><br>";
                $formatted .= "<pre class='json-response'>" . htmlspecialchars($formatted_json) . "</pre></div>";
            } else {
                // If not valid JSON, show as regular text
                $formatted .= "<div class='log-field'><strong>" . ucfirst(str_replace('_', ' ', $key)) . ":</strong> " . htmlspecialchars($value) . "</div>";
            }
        } else {
            $formatted .= "<div class='log-field'><strong>" . ucfirst(str_replace('_', ' ', $key)) . ":</strong> " . htmlspecialchars($value) . "</div>";
        }
    }
    
    $formatted .= "</div>";
    return $formatted;
}

$available_dates = get_available_dates($log_dir, $log_type);
$log_file = $log_dir . '/' . $log_type . '_' . $date . '.log';
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FastConnect VPN Log Viewer</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #f5f5f5;
            height: 100vh;
            overflow: hidden;
        }
        .container {
            max-width: none;
            width: 100%;
            height: 100vh;
            margin: 0;
            background: white;
            border-radius: 0;
            box-shadow: none;
            overflow: hidden;
            display: flex;
            flex-direction: column;
        }
        .header {
            background: #059669;
            color: white;
            padding: 20px;
            flex-shrink: 0;
        }
        .header h1 {
            margin: 0;
            font-size: 24px;
        }
        .controls {
            padding: 20px;
            border-bottom: 1px solid #e5e7eb;
            background: #f9fafb;
            flex-shrink: 0;
        }
        .controls select, .controls button {
            padding: 8px 12px;
            margin-right: 10px;
            border: 1px solid #d1d5db;
            border-radius: 4px;
            background: white;
        }
        .controls button {
            background: #059669;
            color: white;
            cursor: pointer;
        }
        .controls button:hover {
            background: #047857;
        }
        .log-content {
            padding: 20px;
            flex: 1;
            overflow-y: auto;
            height: 0;
        }
        .log-entry {
            background: #f8fafc;
            border: 1px solid #e2e8f0;
            border-radius: 6px;
            padding: 15px;
            margin-bottom: 15px;
        }
        .timestamp {
            font-weight: bold;
            color: #059669;
            margin-bottom: 10px;
            font-size: 14px;
        }
        .log-field {
            margin-bottom: 5px;
            font-size: 13px;
            line-height: 1.4;
        }
        .log-field strong {
            color: #374151;
            min-width: 120px;
            display: inline-block;
        }
        .stats {
            background: #eff6ff;
            border: 1px solid #bfdbfe;
            border-radius: 6px;
            padding: 15px;
            margin-bottom: 20px;
        }
        .no-logs {
            text-align: center;
            color: #6b7280;
            padding: 40px;
        }
        .tab {
            display: inline-block;
            padding: 10px 20px;
            margin-right: 5px;
            background: #e5e7eb;
            border-radius: 6px 6px 0 0;
            text-decoration: none;
            color: #374151;
        }
        .tab.active {
            background: #059669;
            color: white;
        }
        .json-response {
            background: #1f2937;
            color: #f9fafb;
            padding: 12px;
            border-radius: 6px;
            font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
            font-size: 12px;
            line-height: 1.5;
            overflow-x: auto;
            margin-top: 8px;
            border: 1px solid #374151;
            white-space: pre-wrap;
            word-wrap: break-word;
        }
        .log-field .json-response {
            margin-left: 0;
            max-height: 300px;
            overflow-y: auto;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>FastConnect VPN Log Viewer</h1>
        </div>
        
        <div class="controls">
            <a href="?type=requests&date=<?php echo $date; ?>" class="tab <?php echo $log_type === 'requests' ? 'active' : ''; ?>">
                Request Logs
            </a>
            <a href="?type=api_responses&date=<?php echo $date; ?>" class="tab <?php echo $log_type === 'api_responses' ? 'active' : ''; ?>">
                API Response Logs
            </a>
            
            <form method="GET" style="display: inline-block; margin-left: 20px;">
                <input type="hidden" name="type" value="<?php echo htmlspecialchars($log_type); ?>">
                <select name="date" onchange="this.form.submit()">
                    <?php foreach ($available_dates as $available_date): ?>
                        <option value="<?php echo $available_date; ?>" <?php echo $available_date === $date ? 'selected' : ''; ?>>
                            <?php echo $available_date; ?>
                        </option>
                    <?php endforeach; ?>
                </select>
                <button type="submit">View Date</button>
            </form>
            
            <button onclick="location.reload()">Refresh</button>
        </div>
        
        <div class="log-content">
            <?php if (file_exists($log_file)): ?>
                <?php
                $log_content = file_get_contents($log_file);
                $log_entries = array_filter(explode("\n", $log_content));
                $total_entries = count($log_entries);
                ?>
                
                <div class="stats">
                    <strong>Log Statistics:</strong><br>
                    File: <?php echo basename($log_file); ?><br>
                    Total entries: <?php echo $total_entries; ?><br>
                    File size: <?php echo number_format(filesize($log_file) / 1024, 2); ?> KB<br>
                    Last modified: <?php echo date('Y-m-d H:i:s', filemtime($log_file)); ?>
                </div>
                
                <?php if ($total_entries > 0): ?>
                    <?php foreach (array_reverse($log_entries) as $entry): ?>
                        <?php echo format_log_entry(trim($entry)); ?>
                    <?php endforeach; ?>
                <?php else: ?>
                    <div class="no-logs">No log entries found for this date.</div>
                <?php endif; ?>
                
            <?php else: ?>
                <div class="no-logs">
                    No log file found for <?php echo htmlspecialchars($date); ?>.<br>
                    Available dates: <?php echo implode(', ', $available_dates) ?: 'None'; ?>
                </div>
            <?php endif; ?>
        </div>
    </div>
</body>
</html> 