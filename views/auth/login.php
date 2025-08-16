<?php require_once __DIR__.'/../../app/core/helpers.php'; $old=$_SESSION['_old_input']['login']??[]; unset($_SESSION['_old_input']['login']);
ob_start(); ?>
<h2>Inloggen</h2>
<p class="muted">Standaard: admin@example.org / <code>admin123</code> (verander dit direct)</p>
<form method="post" action="<?=h(baseurl('/?p=login.post'))?>">
  <input type="hidden" name="csrf" value="<?=h(csrf_token())?>">
  <label>E-mail <input type="email" name="email" value="<?=h($old['email']??'')?>" required></label>
  <label>Wachtwoord <input type="password" name="password" required></label>
  <button>Inloggen</button>
</form>
<?php $content=ob_get_clean(); include __DIR__.'/../partials/layout.php';
