<?php require_once __DIR__.'/../../app/services/users.php'; require_login('coordinator');
$all=users_all();
ob_start(); ?>
<h2>Gebruikers</h2>
<table>
  <thead><tr><th>Naam</th><th>Email</th><th>Rol</th></tr></thead>
  <tbody>
    <?php foreach($all as $u): ?>
      <tr><td><?=h($u['name'])?></td><td><?=h($u['email'])?></td><td><?=h($u['role'])?></td></tr>
    <?php endforeach; ?>
  </tbody>
</table>
<form method="post" action="<?=h(baseurl('/?p=admin.users.add'))?>" class="grid">
  <input type="hidden" name="csrf" value="<?=h(csrf_token())?>">
  <label>Naam <input name="name" required></label>
  <label>Email <input type="email" name="email" required></label>
  <label>Rol
    <select name="role"><option>begeleider</option><option>coordinator</option></select>
  </label>
  <label>Wachtwoord <input type="text" name="password" placeholder="min. 8 tekens" required></label>
  <button>+ Voeg gebruiker toe</button>
</form>
<?php $content=ob_get_clean(); include __DIR__.'/../partials/layout.php';
