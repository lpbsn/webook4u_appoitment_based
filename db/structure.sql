SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: enforce_bookings_client_consistency(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_bookings_client_consistency() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  service_enseigne_id bigint;
  staff_enseigne_id bigint;
  enseigne_client_id bigint;
BEGIN
  SELECT enseigne_id INTO service_enseigne_id
  FROM services
  WHERE id = NEW.service_id;

  IF service_enseigne_id IS NOT NULL AND service_enseigne_id <> NEW.enseigne_id THEN
    RAISE EXCEPTION 'bookings.enseigne_id must match services.enseigne_id'
      USING ERRCODE = '23514';
  END IF;

  IF NEW.staff_id IS NOT NULL THEN
    SELECT enseigne_id INTO staff_enseigne_id
    FROM staffs
    WHERE id = NEW.staff_id;

    IF staff_enseigne_id IS NOT NULL AND staff_enseigne_id <> NEW.enseigne_id THEN
      RAISE EXCEPTION 'bookings.enseigne_id must match staffs.enseigne_id'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  SELECT client_id INTO enseigne_client_id
  FROM enseignes
  WHERE id = NEW.enseigne_id;

  IF enseigne_client_id IS NOT NULL AND enseigne_client_id <> NEW.client_id THEN
    RAISE EXCEPTION 'bookings.client_id must match enseignes.client_id'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: enforce_global_pending_access_token_uniqueness(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_global_pending_access_token_uniqueness() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NULLIF(BTRIM(NEW.pending_access_token), '') IS NULL THEN
    RETURN NEW;
  END IF;

  IF TG_TABLE_NAME = 'bookings' THEN
    IF EXISTS (
      SELECT 1
      FROM expired_booking_links ebl
      WHERE ebl.pending_access_token = NEW.pending_access_token
    ) THEN
      RAISE EXCEPTION 'pending_access_token must be globally unique across bookings and expired_booking_links'
        USING ERRCODE = '23505';
    END IF;
  ELSIF TG_TABLE_NAME = 'expired_booking_links' THEN
    IF EXISTS (
      SELECT 1
      FROM bookings b
      WHERE b.pending_access_token = NEW.pending_access_token
    ) THEN
      RAISE EXCEPTION 'pending_access_token must be globally unique across bookings and expired_booking_links'
        USING ERRCODE = '23505';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: bookings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bookings (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    service_id bigint NOT NULL,
    customer_email character varying,
    booking_start_time timestamp(6) without time zone NOT NULL,
    booking_end_time timestamp(6) without time zone NOT NULL,
    booking_status character varying NOT NULL,
    booking_expires_at timestamp(6) without time zone,
    stripe_session_id character varying,
    stripe_payment_intent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    customer_first_name character varying,
    customer_last_name character varying,
    confirmation_token character varying,
    enseigne_id bigint NOT NULL,
    pending_access_token character varying,
    staff_id bigint,
    CONSTRAINT bookings_confirmed_requires_confirmation_token CHECK ((((booking_status)::text <> 'confirmed'::text) OR (NULLIF(btrim((confirmation_token)::text), ''::text) IS NOT NULL))),
    CONSTRAINT bookings_confirmed_requires_customer_email CHECK ((((booking_status)::text <> 'confirmed'::text) OR (NULLIF(btrim((customer_email)::text), ''::text) IS NOT NULL))),
    CONSTRAINT bookings_confirmed_requires_customer_first_name CHECK ((((booking_status)::text <> 'confirmed'::text) OR (NULLIF(btrim((customer_first_name)::text), ''::text) IS NOT NULL))),
    CONSTRAINT bookings_confirmed_requires_customer_last_name CHECK ((((booking_status)::text <> 'confirmed'::text) OR (NULLIF(btrim((customer_last_name)::text), ''::text) IS NOT NULL))),
    CONSTRAINT bookings_end_time_after_start_time CHECK ((booking_end_time > booking_start_time)),
    CONSTRAINT bookings_pending_requires_booking_expires_at CHECK ((((booking_status)::text <> 'pending'::text) OR (booking_expires_at IS NOT NULL))),
    CONSTRAINT bookings_pending_requires_pending_access_token CHECK ((((booking_status)::text <> 'pending'::text) OR (NULLIF(btrim((pending_access_token)::text), ''::text) IS NOT NULL))),
    CONSTRAINT bookings_status_allowed_values CHECK (((booking_status)::text = ANY (ARRAY[('pending'::character varying)::text, ('confirmed'::character varying)::text, ('failed'::character varying)::text])))
);


--
-- Name: bookings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bookings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bookings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bookings_id_seq OWNED BY public.bookings.id;


--
-- Name: client_opening_hours; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_opening_hours (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    day_of_week integer NOT NULL,
    opens_at time without time zone NOT NULL,
    closes_at time without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT client_opening_hours_opens_before_closes CHECK ((opens_at < closes_at))
);


--
-- Name: client_opening_hours_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_opening_hours_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_opening_hours_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_opening_hours_id_seq OWNED BY public.client_opening_hours.id;


--
-- Name: clients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.clients (
    id bigint NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT clients_name_not_blank CHECK ((NULLIF(btrim((name)::text), ''::text) IS NOT NULL))
);


--
-- Name: clients_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.clients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: clients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.clients_id_seq OWNED BY public.clients.id;


--
-- Name: enseigne_opening_hours; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enseigne_opening_hours (
    id bigint NOT NULL,
    enseigne_id bigint NOT NULL,
    day_of_week integer NOT NULL,
    opens_at time without time zone NOT NULL,
    closes_at time without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT enseigne_opening_hours_opens_before_closes CHECK ((opens_at < closes_at))
);


--
-- Name: enseigne_opening_hours_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.enseigne_opening_hours_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enseigne_opening_hours_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.enseigne_opening_hours_id_seq OWNED BY public.enseigne_opening_hours.id;


--
-- Name: enseignes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enseignes (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    name character varying NOT NULL,
    full_address character varying,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: enseignes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.enseignes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enseignes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.enseignes_id_seq OWNED BY public.enseignes.id;


--
-- Name: expired_booking_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.expired_booking_links (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    pending_access_token character varying NOT NULL,
    enseigne_id bigint,
    service_id bigint,
    booking_date date NOT NULL,
    expired_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: expired_booking_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.expired_booking_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: expired_booking_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.expired_booking_links_id_seq OWNED BY public.expired_booking_links.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: service_assignment_cursors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.service_assignment_cursors (
    id bigint NOT NULL,
    service_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: service_assignment_cursors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.service_assignment_cursors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: service_assignment_cursors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.service_assignment_cursors_id_seq OWNED BY public.service_assignment_cursors.id;


--
-- Name: services; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.services (
    id bigint NOT NULL,
    client_id bigint,
    name character varying NOT NULL,
    duration_minutes integer NOT NULL,
    price_cents integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    enseigne_id bigint NOT NULL,
    CONSTRAINT services_duration_minutes_positive CHECK ((duration_minutes > 0)),
    CONSTRAINT services_price_cents_non_negative CHECK ((price_cents >= 0))
);


--
-- Name: services_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.services_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: services_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.services_id_seq OWNED BY public.services.id;


--
-- Name: staff_availabilities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff_availabilities (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    day_of_week integer NOT NULL,
    opens_at time without time zone NOT NULL,
    closes_at time without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: staff_availabilities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.staff_availabilities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff_availabilities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staff_availabilities_id_seq OWNED BY public.staff_availabilities.id;


--
-- Name: staff_service_capabilities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff_service_capabilities (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    service_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: staff_service_capabilities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.staff_service_capabilities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff_service_capabilities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staff_service_capabilities_id_seq OWNED BY public.staff_service_capabilities.id;


--
-- Name: staff_unavailabilities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff_unavailabilities (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    starts_at timestamp(6) without time zone NOT NULL,
    ends_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: staff_unavailabilities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.staff_unavailabilities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff_unavailabilities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staff_unavailabilities_id_seq OWNED BY public.staff_unavailabilities.id;


--
-- Name: staffs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staffs (
    id bigint NOT NULL,
    enseigne_id bigint NOT NULL,
    name character varying NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: staffs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.staffs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staffs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staffs_id_seq OWNED BY public.staffs.id;


--
-- Name: bookings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings ALTER COLUMN id SET DEFAULT nextval('public.bookings_id_seq'::regclass);


--
-- Name: client_opening_hours id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_opening_hours ALTER COLUMN id SET DEFAULT nextval('public.client_opening_hours_id_seq'::regclass);


--
-- Name: clients id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients ALTER COLUMN id SET DEFAULT nextval('public.clients_id_seq'::regclass);


--
-- Name: enseigne_opening_hours id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enseigne_opening_hours ALTER COLUMN id SET DEFAULT nextval('public.enseigne_opening_hours_id_seq'::regclass);


--
-- Name: enseignes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enseignes ALTER COLUMN id SET DEFAULT nextval('public.enseignes_id_seq'::regclass);


--
-- Name: expired_booking_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expired_booking_links ALTER COLUMN id SET DEFAULT nextval('public.expired_booking_links_id_seq'::regclass);


--
-- Name: service_assignment_cursors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_assignment_cursors ALTER COLUMN id SET DEFAULT nextval('public.service_assignment_cursors_id_seq'::regclass);


--
-- Name: services id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.services ALTER COLUMN id SET DEFAULT nextval('public.services_id_seq'::regclass);


--
-- Name: staff_availabilities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_availabilities ALTER COLUMN id SET DEFAULT nextval('public.staff_availabilities_id_seq'::regclass);


--
-- Name: staff_service_capabilities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_service_capabilities ALTER COLUMN id SET DEFAULT nextval('public.staff_service_capabilities_id_seq'::regclass);


--
-- Name: staff_unavailabilities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_unavailabilities ALTER COLUMN id SET DEFAULT nextval('public.staff_unavailabilities_id_seq'::regclass);


--
-- Name: staffs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staffs ALTER COLUMN id SET DEFAULT nextval('public.staffs_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: bookings bookings_confirmed_no_overlapping_intervals_per_enseigne; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_confirmed_no_overlapping_intervals_per_enseigne EXCLUDE USING gist (enseigne_id WITH =, tsrange(booking_start_time, booking_end_time, '[)'::text) WITH &&) WHERE (((booking_status)::text = 'confirmed'::text));


--
-- Name: bookings bookings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_pkey PRIMARY KEY (id);


--
-- Name: client_opening_hours client_opening_hours_no_overlapping_intervals_per_day; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_opening_hours
    ADD CONSTRAINT client_opening_hours_no_overlapping_intervals_per_day EXCLUDE USING gist (client_id WITH =, day_of_week WITH =, int4range((EXTRACT(epoch FROM opens_at))::integer, (EXTRACT(epoch FROM closes_at))::integer, '[)'::text) WITH &&);


--
-- Name: client_opening_hours client_opening_hours_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_opening_hours
    ADD CONSTRAINT client_opening_hours_pkey PRIMARY KEY (id);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- Name: enseigne_opening_hours enseigne_opening_hours_no_overlapping_intervals_per_day; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enseigne_opening_hours
    ADD CONSTRAINT enseigne_opening_hours_no_overlapping_intervals_per_day EXCLUDE USING gist (enseigne_id WITH =, day_of_week WITH =, int4range((EXTRACT(epoch FROM opens_at))::integer, (EXTRACT(epoch FROM closes_at))::integer, '[)'::text) WITH &&);


--
-- Name: enseigne_opening_hours enseigne_opening_hours_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enseigne_opening_hours
    ADD CONSTRAINT enseigne_opening_hours_pkey PRIMARY KEY (id);


--
-- Name: enseignes enseignes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enseignes
    ADD CONSTRAINT enseignes_pkey PRIMARY KEY (id);


--
-- Name: expired_booking_links expired_booking_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expired_booking_links
    ADD CONSTRAINT expired_booking_links_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: service_assignment_cursors service_assignment_cursors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_assignment_cursors
    ADD CONSTRAINT service_assignment_cursors_pkey PRIMARY KEY (id);


--
-- Name: services services_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_pkey PRIMARY KEY (id);


--
-- Name: staff_availabilities staff_availabilities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_availabilities
    ADD CONSTRAINT staff_availabilities_pkey PRIMARY KEY (id);


--
-- Name: staff_service_capabilities staff_service_capabilities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_service_capabilities
    ADD CONSTRAINT staff_service_capabilities_pkey PRIMARY KEY (id);


--
-- Name: staff_unavailabilities staff_unavailabilities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_unavailabilities
    ADD CONSTRAINT staff_unavailabilities_pkey PRIMARY KEY (id);


--
-- Name: staffs staffs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staffs
    ADD CONSTRAINT staffs_pkey PRIMARY KEY (id);


--
-- Name: index_bookings_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bookings_on_client_id ON public.bookings USING btree (client_id);


--
-- Name: index_bookings_on_confirmation_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_bookings_on_confirmation_token ON public.bookings USING btree (confirmation_token);


--
-- Name: index_bookings_on_enseigne_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bookings_on_enseigne_id ON public.bookings USING btree (enseigne_id);


--
-- Name: index_bookings_on_pending_access_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_bookings_on_pending_access_token ON public.bookings USING btree (pending_access_token);


--
-- Name: index_bookings_on_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bookings_on_service_id ON public.bookings USING btree (service_id);


--
-- Name: index_bookings_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bookings_on_staff_id ON public.bookings USING btree (staff_id);


--
-- Name: index_client_opening_hours_on_client_and_day; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_opening_hours_on_client_and_day ON public.client_opening_hours USING btree (client_id, day_of_week);


--
-- Name: index_client_opening_hours_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_opening_hours_on_client_id ON public.client_opening_hours USING btree (client_id);


--
-- Name: index_client_opening_hours_on_exact_interval_per_day; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_opening_hours_on_exact_interval_per_day ON public.client_opening_hours USING btree (client_id, day_of_week, opens_at, closes_at);


--
-- Name: index_clients_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_clients_on_slug ON public.clients USING btree (slug);


--
-- Name: index_enseigne_opening_hours_on_enseigne_and_day; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_enseigne_opening_hours_on_enseigne_and_day ON public.enseigne_opening_hours USING btree (enseigne_id, day_of_week);


--
-- Name: index_enseigne_opening_hours_on_enseigne_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_enseigne_opening_hours_on_enseigne_id ON public.enseigne_opening_hours USING btree (enseigne_id);


--
-- Name: index_enseigne_opening_hours_on_exact_interval_per_day; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_enseigne_opening_hours_on_exact_interval_per_day ON public.enseigne_opening_hours USING btree (enseigne_id, day_of_week, opens_at, closes_at);


--
-- Name: index_enseignes_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_enseignes_on_client_id ON public.enseignes USING btree (client_id);


--
-- Name: index_expired_booking_links_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_expired_booking_links_on_client_id ON public.expired_booking_links USING btree (client_id);


--
-- Name: index_expired_booking_links_on_expired_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_expired_booking_links_on_expired_at ON public.expired_booking_links USING btree (expired_at);


--
-- Name: index_expired_booking_links_on_pending_access_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_expired_booking_links_on_pending_access_token ON public.expired_booking_links USING btree (pending_access_token);


--
-- Name: index_service_assignment_cursors_on_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_service_assignment_cursors_on_service_id ON public.service_assignment_cursors USING btree (service_id);


--
-- Name: index_services_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_services_on_client_id ON public.services USING btree (client_id);


--
-- Name: index_services_on_enseigne_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_services_on_enseigne_id ON public.services USING btree (enseigne_id);


--
-- Name: index_staff_availabilities_on_staff_and_day; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_availabilities_on_staff_and_day ON public.staff_availabilities USING btree (staff_id, day_of_week);


--
-- Name: index_staff_availabilities_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_availabilities_on_staff_id ON public.staff_availabilities USING btree (staff_id);


--
-- Name: index_staff_service_capabilities_on_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_service_capabilities_on_service_id ON public.staff_service_capabilities USING btree (service_id);


--
-- Name: index_staff_service_capabilities_on_staff_and_service; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_staff_service_capabilities_on_staff_and_service ON public.staff_service_capabilities USING btree (staff_id, service_id);


--
-- Name: index_staff_service_capabilities_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_service_capabilities_on_staff_id ON public.staff_service_capabilities USING btree (staff_id);


--
-- Name: index_staff_unavailabilities_on_staff_and_starts_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_unavailabilities_on_staff_and_starts_at ON public.staff_unavailabilities USING btree (staff_id, starts_at);


--
-- Name: index_staff_unavailabilities_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_unavailabilities_on_staff_id ON public.staff_unavailabilities USING btree (staff_id);


--
-- Name: index_staffs_on_enseigne_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staffs_on_enseigne_id ON public.staffs USING btree (enseigne_id);


--
-- Name: bookings bookings_client_consistency_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER bookings_client_consistency_trigger BEFORE INSERT OR UPDATE ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.enforce_bookings_client_consistency();


--
-- Name: bookings bookings_global_pending_access_token_uniqueness_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER bookings_global_pending_access_token_uniqueness_trigger BEFORE INSERT OR UPDATE OF pending_access_token ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.enforce_global_pending_access_token_uniqueness();


--
-- Name: expired_booking_links expired_booking_links_global_pending_access_token_uniqueness_tr; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER expired_booking_links_global_pending_access_token_uniqueness_tr BEFORE INSERT OR UPDATE OF pending_access_token ON public.expired_booking_links FOR EACH ROW EXECUTE FUNCTION public.enforce_global_pending_access_token_uniqueness();


--
-- Name: staff_service_capabilities fk_rails_065b65ec4f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_service_capabilities
    ADD CONSTRAINT fk_rails_065b65ec4f FOREIGN KEY (service_id) REFERENCES public.services(id);


--
-- Name: bookings fk_rails_1707d5de0d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT fk_rails_1707d5de0d FOREIGN KEY (service_id) REFERENCES public.services(id);


--
-- Name: services fk_rails_1b9e100e65; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT fk_rails_1b9e100e65 FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: staff_availabilities fk_rails_26975c979e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_availabilities
    ADD CONSTRAINT fk_rails_26975c979e FOREIGN KEY (staff_id) REFERENCES public.staffs(id);


--
-- Name: bookings fk_rails_2c503ea743; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT fk_rails_2c503ea743 FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: staffs fk_rails_37c9934212; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staffs
    ADD CONSTRAINT fk_rails_37c9934212 FOREIGN KEY (enseigne_id) REFERENCES public.enseignes(id);


--
-- Name: services fk_rails_4b34ba1680; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT fk_rails_4b34ba1680 FOREIGN KEY (enseigne_id) REFERENCES public.enseignes(id);


--
-- Name: staff_unavailabilities fk_rails_5a752a5b3c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_unavailabilities
    ADD CONSTRAINT fk_rails_5a752a5b3c FOREIGN KEY (staff_id) REFERENCES public.staffs(id);


--
-- Name: enseigne_opening_hours fk_rails_5afe3b8c85; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enseigne_opening_hours
    ADD CONSTRAINT fk_rails_5afe3b8c85 FOREIGN KEY (enseigne_id) REFERENCES public.enseignes(id);


--
-- Name: service_assignment_cursors fk_rails_63485c6ee2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_assignment_cursors
    ADD CONSTRAINT fk_rails_63485c6ee2 FOREIGN KEY (service_id) REFERENCES public.services(id);


--
-- Name: client_opening_hours fk_rails_8e88be3c44; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_opening_hours
    ADD CONSTRAINT fk_rails_8e88be3c44 FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: expired_booking_links fk_rails_c2bc6272db; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expired_booking_links
    ADD CONSTRAINT fk_rails_c2bc6272db FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: enseignes fk_rails_cc63fed4c0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enseignes
    ADD CONSTRAINT fk_rails_cc63fed4c0 FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: bookings fk_rails_cf615b8bba; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT fk_rails_cf615b8bba FOREIGN KEY (enseigne_id) REFERENCES public.enseignes(id);


--
-- Name: staff_service_capabilities fk_rails_e926fda810; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_service_capabilities
    ADD CONSTRAINT fk_rails_e926fda810 FOREIGN KEY (staff_id) REFERENCES public.staffs(id);


--
-- Name: bookings fk_rails_f96da13d28; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT fk_rails_f96da13d28 FOREIGN KEY (staff_id) REFERENCES public.staffs(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260402133000'),
('20260402123000'),
('20260402114000'),
('20260402113000'),
('20260402103000'),
('20260402093113'),
('20260402060100'),
('20260402050000'),
('20260402030000'),
('20260401170000'),
('20260401150000'),
('20260401120000'),
('20260325130000'),
('20260325123000'),
('20260325113000'),
('20260325103000'),
('20260325090000'),
('20260325080000'),
('20260325073349'),
('20260325000003'),
('20260325000002'),
('20260325000001'),
('20260324000002'),
('20260324000001'),
('20260319000002'),
('20260319000001'),
('20260318091500'),
('20260318043805'),
('20260316073931'),
('20260315110003'),
('20260315105010'),
('20260315104615'),
('20260315102949'),
('20260315102534'),
('20260314081835'),
('20260314080003'),
('20260314075954');

