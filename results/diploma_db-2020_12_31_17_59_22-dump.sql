--
-- PostgreSQL database dump
--

-- Dumped from database version 13.1
-- Dumped by pg_dump version 13.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

DROP DATABASE IF EXISTS diploma;
--
-- Name: diploma; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE diploma WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'Russian_Russia.1251';


ALTER DATABASE diploma OWNER TO postgres;

\connect diploma

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: metrics; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA metrics;


ALTER SCHEMA metrics OWNER TO postgres;

--
-- Name: rawd; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA rawd;


ALTER SCHEMA rawd OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: raw_result; Type: TABLE; Schema: rawd; Owner: postgres
--

CREATE TABLE rawd.raw_result (
    component character varying(255) NOT NULL,
    cve character varying(255) NOT NULL,
    vendor character varying(255) NOT NULL,
    id integer NOT NULL,
    search_date date DEFAULT now() NOT NULL
);


ALTER TABLE rawd.raw_result OWNER TO postgres;

--
-- Name: duplicates; Type: VIEW; Schema: metrics; Owner: postgres
--

CREATE VIEW metrics.duplicates AS
 WITH dups AS (
         SELECT raw_result.component,
            raw_result.cve,
            raw_result.vendor,
            raw_result.id,
            raw_result.search_date,
            row_number() OVER (PARTITION BY raw_result.vendor, raw_result.component, raw_result.cve, raw_result.search_date) AS num
           FROM rawd.raw_result
        )
 SELECT dups.component,
    dups.cve,
    dups.vendor,
    dups.id,
    dups.search_date,
    dups.num
   FROM dups
  WHERE (dups.num > 1);


ALTER TABLE metrics.duplicates OWNER TO postgres;

--
-- Name: true_positive; Type: VIEW; Schema: metrics; Owner: postgres
--

CREATE VIEW metrics.true_positive AS
SELECT
    NULL::character varying(255) AS component,
    NULL::character varying(255) AS cve,
    NULL::character varying(255) AS vendor,
    NULL::integer AS id,
    NULL::date AS search_date;


ALTER TABLE metrics.true_positive OWNER TO postgres;

--
-- Name: expected; Type: TABLE; Schema: rawd; Owner: postgres
--

CREATE TABLE rawd.expected (
    component character varying(255) NOT NULL,
    cve character varying(255) NOT NULL,
    expected_date date DEFAULT now() NOT NULL
);


ALTER TABLE rawd.expected OWNER TO postgres;

--
-- Name: sca_vendor; Type: TABLE; Schema: rawd; Owner: postgres
--

CREATE TABLE rawd.sca_vendor (
    code character varying(255) NOT NULL,
    full_name character varying(255)
);


ALTER TABLE rawd.sca_vendor OWNER TO postgres;

--
-- Name: false_positive; Type: VIEW; Schema: metrics; Owner: postgres
--

CREATE VIEW metrics.false_positive AS
 SELECT v.code AS vendor,
    ex.component,
    ex.cve
   FROM rawd.sca_vendor v,
    rawd.expected ex
  WHERE (NOT (EXISTS ( SELECT
           FROM metrics.true_positive tp
          WHERE (((tp.vendor)::text = (v.code)::text) AND ((tp.component)::text = (ex.component)::text) AND ((tp.cve)::text = (ex.cve)::text)))));


ALTER TABLE metrics.false_positive OWNER TO postgres;

--
-- Name: true_positive_components; Type: VIEW; Schema: metrics; Owner: postgres
--

CREATE VIEW metrics.true_positive_components AS
 SELECT DISTINCT tp.vendor,
    tp.component
   FROM metrics.true_positive tp
  GROUP BY tp.vendor, tp.component;


ALTER TABLE metrics.true_positive_components OWNER TO postgres;

--
-- Name: false_positive_components; Type: VIEW; Schema: metrics; Owner: postgres
--

CREATE VIEW metrics.false_positive_components AS
 SELECT v.code AS vendor,
    e.component
   FROM rawd.expected e,
    rawd.sca_vendor v
  WHERE (NOT (EXISTS ( SELECT 1
           FROM metrics.true_positive_components tpc
          WHERE (((tpc.component)::text = (e.component)::text) AND ((tpc.vendor)::text = (v.code)::text)))))
  GROUP BY v.code, e.component;


ALTER TABLE metrics.false_positive_components OWNER TO postgres;

--
-- Name: ok1; Type: VIEW; Schema: metrics; Owner: postgres
--

CREATE VIEW metrics.ok1 AS
 SELECT sca.code,
    ( SELECT count(*) AS count
           FROM metrics.true_positive_components tpc
          WHERE ((tpc.vendor)::text = (sca.code)::text)) AS ok1
   FROM rawd.sca_vendor sca;


ALTER TABLE metrics.ok1 OWNER TO postgres;

--
-- Name: ok12; Type: VIEW; Schema: metrics; Owner: postgres
--

CREATE VIEW metrics.ok12 AS
 SELECT v.code,
    count(*) AS ok12
   FROM (rawd.sca_vendor v
     JOIN rawd.raw_result rr ON (((v.code)::text = (rr.vendor)::text)))
  GROUP BY v.code, v.full_name;


ALTER TABLE metrics.ok12 OWNER TO postgres;

--
-- Name: ok13; Type: VIEW; Schema: metrics; Owner: postgres
--

CREATE VIEW metrics.ok13 AS
 WITH dnum AS (
         SELECT raw_result.vendor,
            raw_result.component,
            raw_result.cve,
            row_number() OVER (PARTITION BY raw_result.vendor, raw_result.component, raw_result.cve) AS num
           FROM rawd.raw_result
        )
 SELECT v.code,
    ( SELECT count(*) AS count
           FROM dnum
          WHERE (((dnum.vendor)::text = (v.code)::text) AND (dnum.num > 1))) AS ok13
   FROM rawd.sca_vendor v
  GROUP BY v.code;


ALTER TABLE metrics.ok13 OWNER TO postgres;

--
-- Name: true_negative_components; Type: VIEW; Schema: metrics; Owner: postgres
--

CREATE VIEW metrics.true_negative_components AS
 SELECT rr.vendor,
    rr.component
   FROM rawd.raw_result rr
  WHERE (NOT (EXISTS ( SELECT tpc.vendor,
            tpc.component
           FROM metrics.true_positive_components tpc
          WHERE (((tpc.vendor)::text = (rr.vendor)::text) AND ((tpc.component)::text = (rr.component)::text)))))
  GROUP BY rr.vendor, rr.component;


ALTER TABLE metrics.true_negative_components OWNER TO postgres;

--
-- Name: ok2; Type: VIEW; Schema: metrics; Owner: postgres
--

CREATE VIEW metrics.ok2 AS
 SELECT v.code,
    ( SELECT count(*) AS count
           FROM metrics.true_negative_components tnc
          WHERE ((tnc.vendor)::text = (v.code)::text)) AS ok2
   FROM rawd.sca_vendor v;


ALTER TABLE metrics.ok2 OWNER TO postgres;

--
-- Name: ok3; Type: VIEW; Schema: metrics; Owner: postgres
--

CREATE VIEW metrics.ok3 AS
 SELECT v.code,
    ( SELECT count(*) AS count
           FROM metrics.false_positive_components fpc
          WHERE ((fpc.vendor)::text = (v.code)::text)) AS ok3
   FROM rawd.sca_vendor v;


ALTER TABLE metrics.ok3 OWNER TO postgres;

--
-- Name: ok4; Type: VIEW; Schema: metrics; Owner: postgres
--

CREATE VIEW metrics.ok4 AS
 SELECT v.code,
    ( SELECT count(*) AS count
           FROM metrics.true_positive
          WHERE ((true_positive.vendor)::text = (v.code)::text)) AS ok4
   FROM rawd.sca_vendor v;


ALTER TABLE metrics.ok4 OWNER TO postgres;

--
-- Name: true_negative; Type: VIEW; Schema: metrics; Owner: postgres
--

CREATE VIEW metrics.true_negative AS
 SELECT rr.vendor,
    rr.component,
    rr.cve,
    rr.id,
    rr.search_date
   FROM rawd.raw_result rr
  WHERE (NOT (EXISTS ( SELECT 1
           FROM metrics.true_positive tp
          WHERE (((tp.vendor)::text = (rr.vendor)::text) AND ((tp.component)::text = (rr.component)::text) AND ((tp.cve)::text = (rr.cve)::text)))))
  GROUP BY rr.vendor, rr.component, rr.cve, rr.id, rr.search_date;


ALTER TABLE metrics.true_negative OWNER TO postgres;

--
-- Name: ok5; Type: VIEW; Schema: metrics; Owner: postgres
--

CREATE VIEW metrics.ok5 AS
 SELECT v.code,
    ( SELECT count(*) AS count
           FROM metrics.true_negative
          WHERE ((true_negative.vendor)::text = (v.code)::text)) AS ok5
   FROM rawd.sca_vendor v;


ALTER TABLE metrics.ok5 OWNER TO postgres;

--
-- Name: ok6; Type: VIEW; Schema: metrics; Owner: postgres
--

CREATE VIEW metrics.ok6 AS
 SELECT sca.code,
    ( SELECT count(*) AS count
           FROM metrics.false_positive fp
          WHERE ((fp.vendor)::text = (sca.code)::text)) AS ok6
   FROM rawd.sca_vendor sca;


ALTER TABLE metrics.ok6 OWNER TO postgres;

--
-- Name: metric_result; Type: VIEW; Schema: metrics; Owner: postgres
--

CREATE VIEW metrics.metric_result AS
 SELECT sca.code,
    sca.full_name,
    ok1.ok1,
    ok2.ok2,
    ok3.ok3,
    ok4.ok4,
    ok5.ok5,
    ok6.ok6,
    ok12.ok12,
    ok13.ok13
   FROM ((((((((rawd.sca_vendor sca
     LEFT JOIN metrics.ok1 ON (((ok1.code)::text = (sca.code)::text)))
     LEFT JOIN metrics.ok2 ON (((ok2.code)::text = (sca.code)::text)))
     LEFT JOIN metrics.ok3 ON (((ok3.code)::text = (sca.code)::text)))
     LEFT JOIN metrics.ok4 ON (((ok4.code)::text = (sca.code)::text)))
     LEFT JOIN metrics.ok5 ON (((ok5.code)::text = (sca.code)::text)))
     LEFT JOIN metrics.ok6 ON (((ok6.code)::text = (sca.code)::text)))
     LEFT JOIN metrics.ok12 ON (((ok12.code)::text = (sca.code)::text)))
     LEFT JOIN metrics.ok13 ON (((ok13.code)::text = (sca.code)::text)));


ALTER TABLE metrics.metric_result OWNER TO postgres;

--
-- Name: raw_result_id_seq; Type: SEQUENCE; Schema: rawd; Owner: postgres
--

CREATE SEQUENCE rawd.raw_result_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rawd.raw_result_id_seq OWNER TO postgres;

--
-- Name: raw_result_id_seq; Type: SEQUENCE OWNED BY; Schema: rawd; Owner: postgres
--

ALTER SEQUENCE rawd.raw_result_id_seq OWNED BY rawd.raw_result.id;


--
-- Name: raw_result id; Type: DEFAULT; Schema: rawd; Owner: postgres
--

ALTER TABLE ONLY rawd.raw_result ALTER COLUMN id SET DEFAULT nextval('rawd.raw_result_id_seq'::regclass);


--
-- Data for Name: expected; Type: TABLE DATA; Schema: rawd; Owner: postgres
--

INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('com.fasterxml.jackson.core:jackson-databind:2.9.10.5', 'CVE-2020-24616', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('com.fasterxml.jackson.core:jackson-databind:2.9.10.5', 'CVE-2020-24750', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('com.fasterxml.jackson.core:jackson-databind:2.9.10.5', 'CVE-2020-25649', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('commons-io:commons-io:2.0', 'sonatype-2018-0705', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.apache.tomcat.embed:tomcat-embed-core:9.0.39', 'CVE-2020-17527', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('com.google.guava:guava:24.0-jre', 'CVE-2018-10237', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2018-1000613', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2018-5382', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000338', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000342', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000343', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000352', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000344', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000341', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000345', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2017-13098', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000339', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2015-7940', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2013-1624', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000346', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2015-6644', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2020-26939', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.springframework:spring-web:3.0.5.RELEASE', 'CVE-2014-0225', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.springframework:spring-web:3.0.5.RELEASE', 'CVE-2013-4152', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.springframework:spring-web:3.0.5.RELEASE', 'CVE-2014-0054', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.springframework:spring-web:3.0.5.RELEASE', 'CVE-2016-1000027', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.springframework:spring-web:3.0.5.RELEASE', 'CVE-2020-5398', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.springframework.boot:spring-boot:2.0.0.M6', 'CWE-79', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2017-5638', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2018-11776', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2017-9791', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2016-6795', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2017-9805', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2017-9787', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2018-1327', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('commons-fileupload:commons-fileupload:1.3.2', 'CVE-2016-1000031', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2012-1007', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('commons-beanutils:commons-beanutils:1.8.0', 'CVE-2014-0114', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('commons-beanutils:commons-beanutils:1.8.0', 'CVE-2019-10086', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('com.google.guava:guava:24.0-jre', 'CVE-2020-8908', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('com.fasterxml.jackson.core:jackson-databind:2.9.10.5', 'CVE-2020-35490', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('com.fasterxml.jackson.core:jackson-databind:2.9.10.5', 'CVE-2020-35491', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.springframework.boot:spring-boot:2.0.0.M6', 'CVE-2018-1196', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2015-0899', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2016-1181', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2016-1182', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2017-12611', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2017-9793', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2017-9804', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2019-0230', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2019-0233', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2020-17530', '2020-12-22');
INSERT INTO rawd.expected (component, cve, expected_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2014-0114', '2020-12-22');


--
-- Data for Name: raw_result; Type: TABLE DATA; Schema: rawd; Owner: postgres
--

INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2015-7940', 'd_track', 207, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000338', 'd_track', 208, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2015-6644', 'd_track', 209, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000344', 'd_track', 210, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2013-1624', 'd_track', 211, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000345', 'd_track', 212, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000352', 'd_track', 213, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000342', 'd_track', 214, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000343', 'd_track', 215, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('com.fasterxml.jackson.core:jackson-databind:2.9.10.5', 'CVE-2020-24616', 'sonar_gp', 1, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('com.fasterxml.jackson.core:jackson-databind:2.9.10.5', 'CVE-2020-24750', 'sonar_gp', 2, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('com.fasterxml.jackson.core:jackson-databind:2.9.10.5', 'CVE-2020-25649', 'sonar_gp', 3, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.tomcat.embed:tomcat-embed-core:9.0.39', 'CVE-2020-17527', 'sonar_gp', 4, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('com.google.guava:guava:24.0-jre', 'CVE-2018-10237', 'sonar_gp', 5, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2018-5382', 'sonar_gp', 6, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2018-1000613', 'sonar_gp', 7, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000342', 'sonar_gp', 8, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000343', 'sonar_gp', 9, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000338', 'sonar_gp', 10, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000352', 'sonar_gp', 11, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000344', 'sonar_gp', 12, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2017-13098', 'sonar_gp', 13, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000345', 'sonar_gp', 14, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000341', 'sonar_gp', 15, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000339', 'sonar_gp', 16, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2020-26939', 'sonar_gp', 17, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2015-7940', 'sonar_gp', 18, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2020-26939', 'd_track', 216, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000346', 'd_track', 217, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2017-13098', 'd_track', 218, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2018-1000613', 'd_track', 219, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000341', 'd_track', 220, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000339', 'd_track', 221, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2018-5382', 'd_track', 222, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('commons-beanutils:commons-beanutils:1.8.0', 'CVE-2014-0114', 'd_track', 223, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('commons-beanutils:commons-beanutils:1.8.0', 'CVE-2019-10086', 'd_track', 224, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('commons-fileupload:commons-fileupload:1.3.2', 'CVE-2016-1000031', 'd_track', 225, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('com.google.guava:guava:24.0-jre', 'CVE-2018-10237', 'd_track', 226, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('com.fasterxml.jackson.core:jackson-databind:2.9.10.5', 'CVE-2020-24750', 'd_track', 227, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('com.fasterxml.jackson.core:jackson-databind:2.9.10.5', 'CVE-2020-24616', 'd_track', 228, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('com.fasterxml.jackson.core:jackson-databind:2.9.10.5', 'CVE-2020-25649', 'd_track', 229, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework.boot:spring-boot:2.0.0.M6', 'CWE-79', 'd_track', 230, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-web:3.0.5.RELEASE', 'CVE-2013-4152', 'd_track', 231, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-web:3.0.5.RELEASE', 'CVE-2014-0054', 'd_track', 232, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-web:3.0.5.RELEASE', 'CVE-2014-0225', 'd_track', 233, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2013-1965', 'd_track', 234, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2013-2135', 'd_track', 235, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2013-2134', 'd_track', 236, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2014-0113', 'd_track', 237, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2013-1624', 'd_check', 53, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2013-1966', 'd_track', 238, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2013-2115', 'd_track', 239, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2016-0785', 'd_track', 240, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2014-0094', 'd_track', 241, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2016-4003', 'd_track', 242, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2011-5057', 'd_track', 243, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2012-0838', 'd_track', 244, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2012-0394', 'd_track', 245, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2012-0391', 'd_track', 246, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2012-1007', 'd_track', 247, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2012-0393', 'd_track', 248, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2012-0392', 'd_track', 249, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2015-2992', 'd_track', 250, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2017-9791', 'd_track', 251, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2016-6795', 'd_track', 252, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2017-9805', 'd_track', 253, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2017-9787', 'd_track', 254, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2017-5638', 'd_track', 255, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2018-1327', 'd_track', 256, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2018-11776', 'd_track', 257, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.tomcat.embed:tomcat-embed-core:9.0.39', 'CVE-2020-17527', 'd_track', 258, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2015-6644', 'd_check', 54, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2015-7940', 'd_check', 55, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000338', 'd_check', 56, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000339', 'd_check', 57, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000341', 'd_check', 58, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000342', 'd_check', 59, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000343', 'd_check', 60, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000344', 'd_check', 61, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000345', 'd_check', 62, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000346', 'd_check', 63, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000352', 'd_check', 64, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2017-13098', 'd_check', 65, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2018-1000613', 'd_check', 66, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2018-5382', 'd_check', 67, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2020-26939', 'd_check', 68, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('commons-beanutils:commons-beanutils:1.8.0', 'CVE-2014-0114', 'd_check', 69, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('commons-beanutils:commons-beanutils:1.8.0', 'CVE-2019-10086', 'd_check', 70, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('commons-fileupload:commons-fileupload:1.3.2', 'CVE-2016-1000031', 'd_check', 71, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('com.google.guava:guava:24.0-jre', 'CVE-2018-10237', 'd_check', 72, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('com.google.guava:guava:24.0-jre', 'CVE-2020-8908', 'd_check', 73, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('com.fasterxml.jackson.core:jackson-databind:2.9.10.5', 'CVE-2020-24616', 'd_check', 74, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('com.fasterxml.jackson.core:jackson-databind:2.9.10.5', 'CVE-2020-24750', 'd_check', 75, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('com.fasterxml.jackson.core:jackson-databind:2.9.10.5', 'CVE-2020-25649', 'd_check', 76, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('com.fasterxml.jackson.core:jackson-databind:2.9.10.5', 'CVE-2020-35490', 'd_check', 77, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('com.fasterxml.jackson.core:jackson-databind:2.9.10.5', 'CVE-2020-35491', 'd_check', 78, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-aop:5.0.1.RELEASE', 'CVE-2018-11039', 'd_check', 79, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-aop:5.0.1.RELEASE', 'CVE-2018-11040', 'd_check', 80, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-aop:5.0.1.RELEASE', 'CVE-2018-1199', 'd_check', 81, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-aop:5.0.1.RELEASE', 'CVE-2018-1257', 'd_check', 82, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-aop:5.0.1.RELEASE', 'CVE-2018-1270', 'd_check', 83, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-aop:5.0.1.RELEASE', 'CVE-2018-1271', 'd_check', 84, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-aop:5.0.1.RELEASE', 'CVE-2018-1272', 'd_check', 85, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-aop:5.0.1.RELEASE', 'CVE-2018-1275', 'd_check', 86, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-aop:5.0.1.RELEASE', 'CVE-2018-15756', 'd_check', 87, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-aop:5.0.1.RELEASE', 'CVE-2020-5398', 'd_check', 88, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-aop:5.0.1.RELEASE', 'CVE-2020-5421', 'd_check', 89, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-beans:5.0.1.RELEASE', 'CVE-2018-11039', 'd_check', 90, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-beans:5.0.1.RELEASE', 'CVE-2018-11040', 'd_check', 91, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-beans:5.0.1.RELEASE', 'CVE-2018-1199', 'd_check', 92, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-beans:5.0.1.RELEASE', 'CVE-2018-1257', 'd_check', 93, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-beans:5.0.1.RELEASE', 'CVE-2018-1270', 'd_check', 94, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-beans:5.0.1.RELEASE', 'CVE-2018-1271', 'd_check', 95, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-beans:5.0.1.RELEASE', 'CVE-2018-1272', 'd_check', 96, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-beans:5.0.1.RELEASE', 'CVE-2018-1275', 'd_check', 97, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-beans:5.0.1.RELEASE', 'CVE-2018-15756', 'd_check', 98, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-beans:5.0.1.RELEASE', 'CVE-2020-5398', 'd_check', 99, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-beans:5.0.1.RELEASE', 'CVE-2020-5421', 'd_check', 100, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework.boot:spring-boot:2.0.0.M6', 'CVE-2018-1196', 'd_check', 101, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework.boot:spring-boot:2.0.0.M6', 'CWE-79', 'd_check', 102, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-context:5.0.1.RELEASE', 'CVE-2018-11039', 'd_check', 103, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-context:5.0.1.RELEASE', 'CVE-2018-11040', 'd_check', 104, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-context:5.0.1.RELEASE', 'CVE-2018-1199', 'd_check', 105, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-context:5.0.1.RELEASE', 'CVE-2018-1257', 'd_check', 106, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-context:5.0.1.RELEASE', 'CVE-2018-1270', 'd_check', 107, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-context:5.0.1.RELEASE', 'CVE-2018-1271', 'd_check', 108, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-context:5.0.1.RELEASE', 'CVE-2018-1272', 'd_check', 109, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-context:5.0.1.RELEASE', 'CVE-2018-1275', 'd_check', 110, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-context:5.0.1.RELEASE', 'CVE-2018-15756', 'd_check', 111, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-context:5.0.1.RELEASE', 'CVE-2020-5398', 'd_check', 112, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-context:5.0.1.RELEASE', 'CVE-2020-5421', 'd_check', 113, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:3.0.5.RELEASE', 'CVE-2011-2730', 'd_check', 114, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:3.0.5.RELEASE', 'CVE-2011-2894', 'd_check', 115, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:3.0.5.RELEASE', 'CVE-2013-4152', 'd_check', 116, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:3.0.5.RELEASE', 'CVE-2013-6429', 'd_check', 117, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:3.0.5.RELEASE', 'CVE-2013-6430', 'd_check', 118, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:3.0.5.RELEASE', 'CVE-2013-7315', 'd_check', 119, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:3.0.5.RELEASE', 'CVE-2014-0054', 'd_check', 120, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:3.0.5.RELEASE', 'CVE-2014-0225', 'd_check', 121, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:3.0.5.RELEASE', 'CVE-2014-1904', 'd_check', 122, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:3.0.5.RELEASE', 'CVE-2014-3625', 'd_check', 123, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:3.0.5.RELEASE', 'CVE-2016-9878', 'd_check', 124, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:3.0.5.RELEASE', 'CVE-2018-1270', 'd_check', 125, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:3.0.5.RELEASE', 'CVE-2018-1271', 'd_check', 126, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:3.0.5.RELEASE', 'CVE-2018-1272', 'd_check', 127, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:3.0.5.RELEASE', 'CVE-2020-5421', 'd_check', 128, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:5.0.1.RELEASE', 'CVE-2018-11039', 'd_check', 129, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:5.0.1.RELEASE', 'CVE-2018-11040', 'd_check', 130, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:5.0.1.RELEASE', 'CVE-2018-1199', 'd_check', 131, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:5.0.1.RELEASE', 'CVE-2018-1257', 'd_check', 132, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:5.0.1.RELEASE', 'CVE-2018-1270', 'd_check', 133, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:5.0.1.RELEASE', 'CVE-2018-1271', 'd_check', 134, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:5.0.1.RELEASE', 'CVE-2018-1272', 'd_check', 135, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:5.0.1.RELEASE', 'CVE-2018-1275', 'd_check', 136, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:5.0.1.RELEASE', 'CVE-2018-15756', 'd_check', 137, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:5.0.1.RELEASE', 'CVE-2020-5398', 'd_check', 138, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-core:5.0.1.RELEASE', 'CVE-2020-5421', 'd_check', 139, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-expression:5.0.1.RELEASE', 'CVE-2018-11039', 'd_check', 140, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-expression:5.0.1.RELEASE', 'CVE-2018-11040', 'd_check', 141, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-expression:5.0.1.RELEASE', 'CVE-2018-1199', 'd_check', 142, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-expression:5.0.1.RELEASE', 'CVE-2018-1257', 'd_check', 143, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-expression:5.0.1.RELEASE', 'CVE-2018-1270', 'd_check', 144, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-expression:5.0.1.RELEASE', 'CVE-2018-1271', 'd_check', 145, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-expression:5.0.1.RELEASE', 'CVE-2018-1272', 'd_check', 146, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-expression:5.0.1.RELEASE', 'CVE-2018-1275', 'd_check', 147, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-expression:5.0.1.RELEASE', 'CVE-2018-15756', 'd_check', 148, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-expression:5.0.1.RELEASE', 'CVE-2020-5398', 'd_check', 149, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-expression:5.0.1.RELEASE', 'CVE-2020-5421', 'd_check', 150, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-jcl:5.0.1.RELEASE', 'CVE-2018-11039', 'd_check', 151, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-jcl:5.0.1.RELEASE', 'CVE-2018-11040', 'd_check', 152, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-jcl:5.0.1.RELEASE', 'CVE-2018-1199', 'd_check', 153, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-jcl:5.0.1.RELEASE', 'CVE-2018-1257', 'd_check', 154, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-jcl:5.0.1.RELEASE', 'CVE-2018-1270', 'd_check', 155, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-jcl:5.0.1.RELEASE', 'CVE-2018-1271', 'd_check', 156, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-jcl:5.0.1.RELEASE', 'CVE-2018-1272', 'd_check', 157, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-jcl:5.0.1.RELEASE', 'CVE-2018-1275', 'd_check', 158, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-jcl:5.0.1.RELEASE', 'CVE-2018-15756', 'd_check', 159, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-jcl:5.0.1.RELEASE', 'CVE-2020-5398', 'd_check', 160, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-jcl:5.0.1.RELEASE', 'CVE-2020-5421', 'd_check', 161, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-web:3.0.5.RELEASE', 'CVE-2013-4152', 'd_check', 162, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-web:3.0.5.RELEASE', 'CVE-2014-0054', 'd_check', 163, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-web:3.0.5.RELEASE', 'CVE-2014-0225', 'd_check', 164, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2011-5057', 'd_check', 165, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2012-0391', 'd_check', 166, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2012-0392', 'd_check', 167, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2012-0393', 'd_check', 168, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2012-0394', 'd_check', 169, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2012-0838', 'd_check', 170, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2012-1007', 'd_check', 171, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2013-1965', 'd_check', 172, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2013-1966', 'd_check', 173, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2013-2115', 'd_check', 174, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2013-2134', 'd_check', 175, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2013-2135', 'd_check', 176, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2014-0094', 'd_check', 177, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2014-0113', 'd_check', 178, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2014-0114', 'd_check', 179, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2015-0899', 'd_check', 180, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2015-2992', 'd_check', 181, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2016-0785', 'd_check', 182, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2016-1181', 'd_check', 183, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2016-1182', 'd_check', 184, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2016-4003', 'd_check', 185, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-taglib:1.3.10', 'CVE-2012-0394', 'd_check', 186, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-taglib:1.3.10', 'CVE-2012-1007', 'd_check', 187, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-taglib:1.3.10', 'CVE-2014-0114', 'd_check', 188, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-taglib:1.3.10', 'CVE-2015-0899', 'd_check', 189, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-taglib:1.3.10', 'CVE-2015-2992', 'd_check', 190, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-taglib:1.3.10', 'CVE-2016-1181', 'd_check', 191, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-taglib:1.3.10', 'CVE-2016-1182', 'd_check', 192, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2016-6795', 'd_check', 193, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2017-12611', 'd_check', 194, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2017-5638', 'd_check', 195, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2017-9787', 'd_check', 196, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2017-9791', 'd_check', 197, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2017-9793', 'd_check', 198, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2017-9804', 'd_check', 199, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2017-9805', 'd_check', 200, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2018-11776', 'd_check', 201, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2018-1327', 'd_check', 202, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2019-0230', 'd_check', 203, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2019-0233', 'd_check', 204, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2020-17530', 'd_check', 205, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.tomcat.embed:tomcat-embed-core:9.0.39', 'CVE-2020-17527', 'd_check', 206, '2020-12-26');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2013-1624', 'sonar_gp', 19, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2016-1000346', 'sonar_gp', 20, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.bouncycastle:bcprov-jdk16:1.46', 'CVE-2015-6644', 'sonar_gp', 21, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework.boot:spring-boot:2.0.0.M6', 'CWE-79', 'sonar_gp', 22, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2017-5638', 'sonar_gp', 23, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2017-9791', 'sonar_gp', 24, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2016-6795', 'sonar_gp', 25, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2018-11776', 'sonar_gp', 26, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2017-9805', 'sonar_gp', 27, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2018-1327', 'sonar_gp', 28, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts2-core:2.3.30', 'CVE-2017-9787', 'sonar_gp', 29, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('commons-fileupload:commons-fileupload:1.3.2', 'CVE-2016-1000031', 'sonar_gp', 30, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-web:3.0.5.RELEASE', 'CVE-2014-0225', 'sonar_gp', 31, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-web:3.0.5.RELEASE', 'CVE-2014-0054', 'sonar_gp', 32, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.springframework:spring-web:3.0.5.RELEASE', 'CVE-2013-4152', 'sonar_gp', 33, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2012-0838', 'sonar_gp', 34, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2013-1966', 'sonar_gp', 35, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2012-0392', 'sonar_gp', 36, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2012-0391', 'sonar_gp', 37, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2013-2134', 'sonar_gp', 38, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2013-2135', 'sonar_gp', 39, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2013-2115', 'sonar_gp', 40, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2013-1965', 'sonar_gp', 41, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2016-0785', 'sonar_gp', 42, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2014-0113', 'sonar_gp', 43, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2012-0394', 'sonar_gp', 44, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2012-0393', 'sonar_gp', 45, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2016-4003', 'sonar_gp', 46, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2015-2992', 'sonar_gp', 47, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2014-0094', 'sonar_gp', 48, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2011-5057', 'sonar_gp', 49, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('org.apache.struts:struts-core:1.3.10', 'CVE-2012-1007', 'sonar_gp', 50, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('commons-beanutils:commons-beanutils:1.8.0', 'CVE-2014-0114', 'sonar_gp', 51, '2020-12-23');
INSERT INTO rawd.raw_result (component, cve, vendor, id, search_date) VALUES ('commons-beanutils:commons-beanutils:1.8.0', 'CVE-2019-10086', 'sonar_gp', 52, '2020-12-23');


--
-- Data for Name: sca_vendor; Type: TABLE DATA; Schema: rawd; Owner: postgres
--

INSERT INTO rawd.sca_vendor (code, full_name) VALUES ('d_track', 'Dependency Track');
INSERT INTO rawd.sca_vendor (code, full_name) VALUES ('d_check', 'OWASP Dependency-Check');
INSERT INTO rawd.sca_vendor (code, full_name) VALUES ('sonar_gp', 'Sonatype Scan Gradle Plugin');


--
-- Name: raw_result_id_seq; Type: SEQUENCE SET; Schema: rawd; Owner: postgres
--

SELECT pg_catalog.setval('rawd.raw_result_id_seq', 258, true);


--
-- Name: expected expected_pk; Type: CONSTRAINT; Schema: rawd; Owner: postgres
--

ALTER TABLE ONLY rawd.expected
    ADD CONSTRAINT expected_pk PRIMARY KEY (component, cve);


--
-- Name: raw_result raw_result_pk; Type: CONSTRAINT; Schema: rawd; Owner: postgres
--

ALTER TABLE ONLY rawd.raw_result
    ADD CONSTRAINT raw_result_pk PRIMARY KEY (id);


--
-- Name: sca_vendor sca_vendor_pk; Type: CONSTRAINT; Schema: rawd; Owner: postgres
--

ALTER TABLE ONLY rawd.sca_vendor
    ADD CONSTRAINT sca_vendor_pk PRIMARY KEY (code);


--
-- Name: expected_component_cve_index; Type: INDEX; Schema: rawd; Owner: postgres
--

CREATE INDEX expected_component_cve_index ON rawd.expected USING btree (component, cve);


--
-- Name: expected_component_index; Type: INDEX; Schema: rawd; Owner: postgres
--

CREATE INDEX expected_component_index ON rawd.expected USING btree (component);


--
-- Name: expected_cve_index; Type: INDEX; Schema: rawd; Owner: postgres
--

CREATE INDEX expected_cve_index ON rawd.expected USING btree (cve);


--
-- Name: raw_result_component_cwe_vendor_index; Type: INDEX; Schema: rawd; Owner: postgres
--

CREATE INDEX raw_result_component_cwe_vendor_index ON rawd.raw_result USING btree (component, cve, vendor);


--
-- Name: raw_result_component_index; Type: INDEX; Schema: rawd; Owner: postgres
--

CREATE INDEX raw_result_component_index ON rawd.raw_result USING btree (component);


--
-- Name: raw_result_vendor_index; Type: INDEX; Schema: rawd; Owner: postgres
--

CREATE INDEX raw_result_vendor_index ON rawd.raw_result USING btree (vendor);


--
-- Name: true_positive _RETURN; Type: RULE; Schema: metrics; Owner: postgres
--

CREATE OR REPLACE VIEW metrics.true_positive AS
 SELECT rr.component,
    rr.cve,
    rr.vendor,
    rr.id,
    rr.search_date
   FROM (rawd.raw_result rr
     JOIN rawd.expected e ON ((((e.component)::text = (rr.component)::text) AND ((e.cve)::text = (rr.cve)::text))))
  WHERE (NOT (EXISTS ( SELECT 1
           FROM metrics.duplicates d
          WHERE (d.id = rr.id))))
  GROUP BY rr.vendor, rr.component, rr.cve, rr.id;


--
-- Name: raw_result raw_result_sca_vendor_name_fk; Type: FK CONSTRAINT; Schema: rawd; Owner: postgres
--

ALTER TABLE ONLY rawd.raw_result
    ADD CONSTRAINT raw_result_sca_vendor_name_fk FOREIGN KEY (vendor) REFERENCES rawd.sca_vendor(code);


--
-- PostgreSQL database dump complete
--

