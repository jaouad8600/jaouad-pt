<form class="card" method="post" action="?p=session&do=save">
  <h2>Nieuw sport/creatief moment</h2>
  <label>Datum</label><input type="date" name="date" value="<?=h(today())?>" required>
  <div class="grid grid3">
    <div><label>Groep</label><input name="group_name" required></div>
    <div><label>Aantal jongeren</label><input type="number" name="youth_count" min="0" required></div>
    <div><label>Type</label>
      <select name="kind"><option>sport</option><option>creatief</option></select>
    </div>
  </div>
  <label>Sfeer op de groep</label><input name="mood" placeholder="rustig / gespannen / ...">
  <label>Ingezette interventies</label><textarea name="interventions" rows="3"></textarea>
  <label>Verloop van de sessie</label><textarea name="progress" rows="4"></textarea>
  <label>Opmerkingen</label><textarea name="remarks" rows="3"></textarea>
  <div class="grid grid2">
    <div><label>Naam invuller</label><input name="submitted_by" required></div>
  </div>
  <button>Opslaan</button>
</form>
