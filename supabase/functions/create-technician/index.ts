// Membuat akun teknisi / admin / pemantau klaim baru.
//
// Fungsi ini berjalan di server Supabase, bukan di aplikasi. Alasannya:
// membuat user butuh service_role key, dan kunci itu tidak boleh ada di
// dalam APK atau exe -- siapa pun yang membongkarnya akan bisa menembus
// seluruh aturan RLS.
//
// Alur:
//   1. periksa token pemanggil
//   2. pastikan dia admin yang aktif
//   3. baru buat user-nya
//
// Deploy: Dashboard > Edge Functions > Deploy a new function > Via Editor

import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return reply({ error: 'Metode tidak didukung' }, 405);

  const url = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  // --- 1. Siapa yang memanggil? ---------------------------------------
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return reply({ error: 'Belum login.' }, 401);

  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error: authErr } = await caller.auth.getUser();
  if (authErr || !user) return reply({ error: 'Sesi tidak valid. Login ulang.' }, 401);

  // --- 2. Hanya admin aktif yang boleh --------------------------------
  const { data: profile } = await caller
    .from('profiles')
    .select('role, aktif')
    .eq('id', user.id)
    .single();

  if (!profile || profile.role !== 'admin' || !profile.aktif) {
    return reply({ error: 'Hanya admin yang dapat menambah pengguna.' }, 403);
  }

  // --- 3. Validasi masukan --------------------------------------------
  let body: { email?: string; password?: string; nama?: string; role?: string };
  try {
    body = await req.json();
  } catch {
    return reply({ error: 'Data tidak terbaca.' }, 400);
  }

  const email = (body.email ?? '').trim().toLowerCase();
  const password = body.password ?? '';
  const nama = (body.nama ?? '').trim();
  const role = ['admin', 'admin_sc', 'teknisi'].includes(body.role ?? '')
    ? body.role!
    : 'teknisi';

  if (!email.includes('@')) return reply({ error: 'Email tidak valid.' }, 400);
  if (password.length < 8) {
    return reply({ error: 'Password minimal 8 karakter.' }, 400);
  }
  if (nama.length < 2) return reply({ error: 'Nama wajib diisi.' }, 400);

  // --- 4. Buat user-nya ------------------------------------------------
  const admin = createClient(url, serviceKey);

  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true, // langsung aktif, tidak perlu verifikasi email
  });

  if (createErr || !created.user) {
    const msg = createErr?.message ?? 'Gagal membuat akun.';
    return reply(
      { error: msg.includes('already') ? 'Email itu sudah terdaftar.' : msg },
      400,
    );
  }

  const { error: profileErr } = await admin.from('profiles').insert({
    id: created.user.id,
    nama,
    role,
  });

  // Kalau profil gagal dibuat, akun auth-nya dihapus lagi. Tanpa ini akan
  // tertinggal user yang bisa login tapi tidak punya nama dan role.
  if (profileErr) {
    await admin.auth.admin.deleteUser(created.user.id);
    return reply({ error: `Gagal menyimpan profil: ${profileErr.message}` }, 400);
  }

  return reply({ id: created.user.id, nama, role });
});
