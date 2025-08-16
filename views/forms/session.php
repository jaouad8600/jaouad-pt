<?php require_once __DIR__.'/../../app/core/helpers.php'; require_login();
$errors = $_SESSION['_old_errors']['session'] ?? [];
$old    = $_SESSION['_old_input']['session']  ?? ['date'=>date('Y-m-d'),'time'=>date('H:i')];
unset($_SESSION['_old_errors']['session'], $_SESSION['_old_input']['session']);
ob_start(); ?>
<h2>Nieuw sport/creatief moment</h2>
<form method="post" action="<?=h(baseurl('/?p=session.save'))?>">
  <input type="hidden" name="csrf" value="<?=h(csrf_token())?>">
  <div class="grid">
    <label>Datum <input type="date" name="date" value="<?=h($old['date']??date('Y-m-d'))?>" required></label>
    <label>Tijd  <input type="time" name="time" value="<?=h($old['time']??date('H:i'))?>"></label>
  </div>
  <div class="grid">
    <label>Groep <input name="group" value="<?=h($old['group']??'')?>" required></label>
    <label>Aantal jongeren <input type="number" name="count" min="0" value="<?=h($old['count']??'0')?>"></label>
  </div>
  <label>Soort
    <select name="kind"><option>Sport</option><option <?=(($old['kind']??'')==='Creatief')?'selected':''?>>Creatief</option></select>
  </label>
  <label>Sfeer <input name="mood" value="<?=h($old['mood']??'')?>"></label>
  <label>Interventies <textarea name="interventions" rows="2"><?=h($old['interventions']??'')?></textarea></label>
  <label>Verloop <textarea name="flow" rows="3"><?=h($old['flow']??'')?></textarea></label>
  <label>Opmerkingen <textarea name="notes" rows="2"><?=h($old['notes']??'')?></textarea></label>
  <button>Opslaan</button> <a class="secondary" href="<?=h(baseurl('/'))?>">Annuleren</a>
</form>
<?php $content=ob_get_clean(); include __DIR__.'/../partials/layout.php';
