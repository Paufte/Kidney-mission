-- KIDNEY MISSION · Registro de jugadores (privado) + ranking público
-- Pega todo esto en Supabase > SQL Editor > New query y pulsa "Run".
-- Se puede ejecutar más de una vez sin problema.

-- 1) Tabla privada: una fila por partida, con los datos de la persona.
create table if not exists public.registros (
  id           uuid primary key default gen_random_uuid(),
  nombre       text not null check (char_length(nombre)    between 1 and 60),
  apellido1    text not null check (char_length(apellido1) between 1 and 60),
  apellido2    text not null check (char_length(apellido2) between 1 and 60),
  email        text not null check (char_length(email) <= 120 and email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  idioma       text check (idioma in ('es','ca')),
  consentimiento boolean not null check (consentimiento),
  inicio       timestamptz not null default now(),
  fin          timestamptz,
  puntuacion   integer check (puntuacion between 0 and 3550),
  aciertos_pct integer check (aciertos_pct between 0 and 100),
  segundos     integer check (segundos between 0 and 7200),
  alias        text
);

-- Nadie con la clave pública puede leer, cambiar ni borrar esta tabla.
-- Solo tú, desde el panel de Supabase (Table Editor).
alter table public.registros enable row level security;
revoke all on public.registros from anon, authenticated;

-- 2) Funciones que usa el juego (lo único que puede hacer la clave pública).
-- Al empezar: guarda los datos y la hora de inicio, y devuelve un código de partida secreto.
create or replace function public.km_registrar(p_nombre text, p_apellido1 text, p_apellido2 text, p_email text, p_idioma text, p_consentimiento boolean)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  insert into public.registros (nombre, apellido1, apellido2, email, idioma, consentimiento)
  values (btrim(p_nombre), btrim(p_apellido1), btrim(p_apellido2), lower(btrim(p_email)),
          case when p_idioma in ('es','ca') then p_idioma end, coalesce(p_consentimiento,false))
  returning id into v_id;
  return v_id;
end $$;

-- Al acabar: guarda puntuación y hora de fin, y publica "Nombre I." en el ranking público.
-- Devuelve la posición en el ranking y el nombre publicado. Solo funciona una vez por partida.
create or replace function public.km_finalizar(p_id uuid, p_puntuacion integer, p_pct integer, p_segundos integer)
returns json language plpgsql security definer set search_path = public as $$
declare r public.registros; v_alias text; v_secs integer; v_pos integer;
begin
  select * into r from public.registros where id = p_id and fin is null for update;
  if not found then raise exception 'partida no valida o ya finalizada'; end if;
  v_secs := greatest(0, least(7200, coalesce(p_segundos, 0)));
  v_alias := btrim(regexp_replace(split_part(r.nombre, ' ', 1), '[^A-Za-z0-9ÁÉÍÓÚÀÈÒÏÜÑÇáéíóúàèòïüñç_.-]', '', 'g'));
  v_alias := left(v_alias, 12) || ' ' || upper(left(regexp_replace(r.apellido1, '[^A-Za-zÁÉÍÓÚÀÈÒÏÜÑÇáéíóúàèòïüñç]', '', 'g'), 1)) || '.';
  if char_length(btrim(v_alias, ' .')) < 2 then v_alias := 'Jugador'; end if;
  update public.registros
     set fin = now(), puntuacion = p_puntuacion, aciertos_pct = p_pct, segundos = v_secs, alias = v_alias
   where id = p_id;
  insert into public.scores (alias, score, pct, secs)
  values (v_alias, p_puntuacion, p_pct, greatest(60, v_secs));
  select count(*) + 1 into v_pos from public.scores
   where score > p_puntuacion or (score = p_puntuacion and secs < greatest(60, v_secs));
  return json_build_object('posicion', v_pos, 'alias', v_alias);
end $$;

revoke all on function public.km_registrar(text,text,text,text,text,boolean) from public;
revoke all on function public.km_finalizar(uuid,integer,integer,integer) from public;
grant execute on function public.km_registrar(text,text,text,text,text,boolean) to anon;
grant execute on function public.km_finalizar(uuid,integer,integer,integer) to anon;

-- 3) Ranking público (pantalla del stand): solo "Nombre I." y puntuación.
-- Ya no se puede añadir puntuaciones directamente: solo a través de km_finalizar.
drop policy if exists "afegir" on public.scores;
revoke insert on public.scores from anon;

-- 4) Vistas para ti (solo visibles desde el panel, no desde la web).
-- Todas las partidas, de la más reciente a la más antigua, con hora de Madrid.
create or replace view public.registros_partidas with (security_invoker = true) as
select nombre, apellido1, apellido2, email, idioma,
       to_char(inicio at time zone 'Europe/Madrid', 'YYYY-MM-DD HH24:MI:SS') as hora_inicio,
       to_char(fin    at time zone 'Europe/Madrid', 'YYYY-MM-DD HH24:MI:SS') as hora_fin,
       puntuacion, aciertos_pct, segundos, alias
  from public.registros order by inicio desc;

-- Clasificación para decidir el ganador: la mejor partida de cada correo.
-- Desempate: menos tiempo y, si sigue empatado, quien la jugó antes.
create or replace view public.registros_clasificacion with (security_invoker = true) as
select row_number() over (order by puntuacion desc, segundos asc, fin asc) as posicion, *
  from (select distinct on (email) email, nombre, apellido1, apellido2, puntuacion, aciertos_pct, segundos,
               to_char(fin at time zone 'Europe/Madrid', 'YYYY-MM-DD HH24:MI:SS') as hora_partida, fin
          from public.registros where fin is not null
         order by email, puntuacion desc, segundos asc, fin asc) t
 order by posicion;

revoke all on public.registros_partidas, public.registros_clasificacion from anon, authenticated;
