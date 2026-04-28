<?php
/**
 * LAMP stack status page — replace this file with your application.
 */

$db_host = getenv('DB_HOST') ?: 'mariadb';
$db_name = getenv('DB_NAME') ?: 'app';
$db_user = getenv('DB_USER') ?: 'app';
$db_pass = getenv('DB_PASS') ?: '';

$db_status  = 'unknown';
$db_version = '';
$db_error   = '';

try {
    $pdo = new PDO("mysql:host=$db_host;dbname=$db_name;charset=utf8mb4", $db_user, $db_pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $db_version = $pdo->query('SELECT VERSION()')->fetchColumn();
    $db_status  = 'connected';
} catch (PDOException $e) {
    $db_status = 'failed';
    $db_error  = $e->getMessage();
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>LAMP Stack</title>
  <style>
    body { font-family: monospace; max-width: 640px; margin: 60px auto; padding: 0 20px; color: #333; }
    h1   { font-size: 1.4rem; margin-bottom: 2rem; }
    table { border-collapse: collapse; width: 100%; }
    th, td { text-align: left; padding: 8px 12px; border-bottom: 1px solid #ddd; }
    th { width: 40%; color: #666; font-weight: normal; }
    .ok   { color: #2a7; font-weight: bold; }
    .fail { color: #c33; font-weight: bold; }
    .note { margin-top: 2rem; font-size: 0.85rem; color: #999; }
  </style>
</head>
<body>
  <h1>LAMP Stack</h1>
  <table>
    <tr><th>PHP version</th><td><?= htmlspecialchars(PHP_VERSION) ?></td></tr>
    <tr><th>Apache version</th><td><?= htmlspecialchars(apache_get_version() ?: 'n/a') ?></td></tr>
    <tr>
      <th>MariaDB</th>
      <td>
        <?php if ($db_status === 'connected'): ?>
          <span class="ok">connected</span> — <?= htmlspecialchars($db_version) ?>
        <?php else: ?>
          <span class="fail">failed</span> — <?= htmlspecialchars($db_error) ?>
        <?php endif; ?>
      </td>
    </tr>
    <tr><th>Extensions</th><td><?= implode(', ', array_filter(['pdo_mysql', 'mysqli', 'mbstring', 'gd', 'zip', 'opcache'], 'extension_loaded')) ?></td></tr>
  </table>
  <p class="note">Replace <code>www/index.php</code> with your application.</p>
</body>
</html>
