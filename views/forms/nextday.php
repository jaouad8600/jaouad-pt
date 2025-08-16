<?php require_once __DIR__.'/../../app/core/helpers.php'; require_login();
$errors=$_SESSION['_old_errors']['nextday']??[]; $old=$_SESSION['_old_input']['nextday']??['date'=>date('Y-m-d')];
unset($_SESSION['_old_errors']['nextday'], $_SESSION['_old_input']['nextday']);
ob_start(); ?>
<h2>Afspraken voor morgen</h2>
<form method="post" action="<?=h(baseurl('/?p=nextday.save'))?>">
  <input type="hidden" name="csrf" value="<?=h(csrf_token())?>">
  <label>Datum (vandaag) <input type="date" name="date" value="<?=h($old['date']??date('Y-m-d'))?>" required></label>
  <label>Groep <input name="group" value="<?=h($old['group']??'')?>" required></label>
  <label>Speciale aandachtspunten <textarea name="special" rows="2"><?=h($old['special']??'')?></textarea></label>
  <label>Sportafspraken <textarea name="sports" rows="2"><?=h($old['sports']??'')?></textarea></label>
  <label>Afspraken met groepsleiding <textarea name="lead" rows="2"><?=h($old['lead']??'')?></textarea></label>
  <button>Opslaan</button> <a class="secondary" href="<?=h(baseurl('/'))?>">Annuleren</a>
</form>
<?php $content=ob_get_clean(); include __DIR__.'/../partials/layout.php';
