<form class="card" method="post" action="?p=incident&do=save">
  <h2>Nieuw incident (kamer-/opvangplaatsing e.d.)</h2>
  <div class="grid grid3">
    <div><label>Datum</label><input type="date" name="date" value="<?=h(today())?>" required></div>
    <div><label>Tijd</label><input type="time" name="time_at" required></div>
    <div><label>Voor & achternaam jongere</label><input name="youth_first" placeholder="Voornaam" style="margin-bottom:8px">
      <input name="youth_last" placeholder="Achternaam"></div>
  </div>
  <label>Korte omschrijving</label><textarea name="summary" rows="4"></textarea>
  <div class="grid grid3">
    <div><label>Melding gedaan?</label>
      <select name="reported"><option value="1">Ja</option><option value="0">Nee</option></select>
    </div>
    <div><label>Jongere gehoord?</label>
      <select name="heard"><option value="1">Ja</option><option value="0">Nee</option></select>
    </div>
    <div><label>Ordemaatregel/Disciplinaire straf</label><input name="measure"></div>
  </div>
  <div class="grid grid2">
    <div><label>Naam invuller</label><input name="submitted_by" required></div>
  </div>
  <button>Opslaan</button>
</form>
