<form class="card" method="post" action="?p=notes&do=save">
  <h2>Afspraken voor morgen</h2>
  <div class="grid grid3">
    <div><label>Datum (morgen of anders)</label><input type="date" name="for_date" value="<?=h(tomorrow())?>" required></div>
    <div><label>Ingevuld door</label><input name="submitted_by" required></div>
  </div>
  <label>Speciale aandachtspunten</label><textarea name="special_attention" rows="3"></textarea>
  <label>Sportafspraken</label><textarea name="sport_appointments" rows="3"></textarea>
  <label>Afspraken met groepsleiding</label><textarea name="group_agreements" rows="3"></textarea>
  <button>Opslaan</button>
</form>
