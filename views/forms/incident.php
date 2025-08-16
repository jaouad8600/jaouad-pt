<?php require_once __DIR__.'/../../app/core/helpers.php'; require_login('coordinator');
$errors=$_SESSION['_old_errors']['incident']??[]; $old=$_SESSION['_old_input']['incident']??['date'=>date('Y-m-d'),'time'=>date('H:i')];
unset($_SESSION['_old_errors']['incident'], $_SESSION['_old_input']['incident']);
ob_start(); ?>
<h2>Incident</h2>
<form method="post" action="<?=h(baseurl('/?p=incident.save'))?>">
  <input type="hidden" name="csrf" value="<?=h(csrf_token())?>">
  <div class="grid">
    <label>Datum <input type="date" name="date" value="<?=h($old['date']??date('Y-m-d'))?>" required></label>
    <label>Tijdstip <input type="time" name="time" value="<?=h($old['time']??date('H:i'))?>"></label>
  </div>
  <label>Voor- en achternaam jongere <input name="y_name" value="<?=h($old['y_name']??'')?>" required></label>
  <label>Korte omschrijving <textarea name="summary" rows="3"><?=h($old['summary']??'')?></textarea></label>
  <div class="grid">
    <label>Incidentmelding gedaan?
      <select name="reported"><option>nee</option><option <?=(($old['reported']??'')==='ja')?'selected':''?>>ja</option></select>
    </label>
    <label>Jongere gehoord?
      <select name="heard"><option>nee</option><option <?=(($old['heard']??'')==='ja')?'selected':''?>>ja</option></select>
    </label>
  </div>
  <label>Ordemaatregel / disciplinaire straf? <input name="measure" value="<?=h($old['measure']??'')?>"></label>
  <button>Opslaan</button> <a class="secondary" href="<?=h(baseurl('/'))?>">Annuleren</a>
</form>
<?php $content=ob_get_clean(); include __DIR__.'/../partials/layout.php';
