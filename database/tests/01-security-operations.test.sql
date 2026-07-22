begin;

do $$
begin
 if to_regclass('public.rate_limit_buckets') is null then raise exception 'rate_limit_buckets missing'; end if;
 if to_regclass('public.economy_events') is null then raise exception 'economy_events missing'; end if;
 if to_regclass('public.admin_audit_log') is null then raise exception 'admin_audit_log missing'; end if;
 if to_regprocedure('public.enforce_rate_limit(text,integer,integer)') is null then raise exception 'enforce_rate_limit missing'; end if;
 if not (select relrowsecurity from pg_class where oid='public.economy_events'::regclass) then raise exception 'economy_events RLS disabled'; end if;
 if not (select relrowsecurity from pg_class where oid='public.admin_audit_log'::regclass) then raise exception 'admin_audit_log RLS disabled'; end if;
end $$;

select 'security_operations_ok' as result;
rollback;
