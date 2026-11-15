-- BookMyShow seed-data schema (PostgreSQL 15+)
CREATE SCHEMA bms;
SET search_path TO bms;

-- Needed for the per-screen exclusion constraint on overlapping show ranges.
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE cities (
    city_id integer PRIMARY KEY,
    city_name varchar(80) NOT NULL UNIQUE,
    state varchar(80) NOT NULL
);

CREATE TABLE venues (
    venue_id integer PRIMARY KEY,
    venue_name varchar(120) NOT NULL,
    city_id integer NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    chain varchar(20) NOT NULL CHECK (chain IN ('PVR','INOX','Cinepolis','Miraj','Independent')),
    address varchar(240) NOT NULL
);

CREATE TABLE screens (
    screen_id integer PRIMARY KEY,
    venue_id integer NOT NULL REFERENCES venues(venue_id) ON DELETE RESTRICT,
    screen_name varchar(40) NOT NULL,
    screen_type varchar(12) NOT NULL CHECK (screen_type IN ('STANDARD','GOLD','IMAX','4DX')),
    total_seats smallint NOT NULL CHECK (total_seats > 0),
    UNIQUE (venue_id, screen_name)
);

CREATE TABLE seats (
    seat_id integer PRIMARY KEY,
    screen_id integer NOT NULL REFERENCES screens(screen_id) ON DELETE RESTRICT,
    row_label char(1) NOT NULL CHECK (row_label ~ '^[A-Z]$'),
    seat_number smallint NOT NULL CHECK (seat_number > 0),
    seat_class varchar(10) NOT NULL CHECK (seat_class IN ('CLASSIC','PRIME','RECLINER')),
    UNIQUE (screen_id, row_label, seat_number)
);

CREATE TABLE movies (
    movie_id integer PRIMARY KEY,
    title varchar(160) NOT NULL,
    language varchar(20) NOT NULL CHECK (language IN ('Hindi','Telugu','Kannada','Bengali','English','Marathi','Tamil','Malayalam')),
    certificate varchar(2) NOT NULL CHECK (certificate IN ('U','UA','A')),
    duration_min smallint NOT NULL CHECK (duration_min BETWEEN 1 AND 600),
    release_date date NOT NULL
);

CREATE TABLE shows (
    show_id integer PRIMARY KEY,
    movie_id integer NOT NULL REFERENCES movies(movie_id) ON DELETE RESTRICT,
    screen_id integer NOT NULL REFERENCES screens(screen_id) ON DELETE RESTRICT,
    starts_at timestamptz NOT NULL,
    ends_at timestamptz NOT NULL,
    format varchar(8) NOT NULL CHECK (format IN ('2D','3D','IMAX','4DX')),
    base_price numeric(8,2) NOT NULL CHECK (base_price >= 0),
    CHECK (ends_at > starts_at),
    EXCLUDE USING gist (screen_id WITH =, tstzrange(starts_at, ends_at, '[)') WITH &&)
);

CREATE TABLE customers (
    customer_id integer PRIMARY KEY,
    full_name varchar(120) NOT NULL,
    email varchar(160) NOT NULL UNIQUE,
    phone varchar(15) NOT NULL UNIQUE,
    city_id integer NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    created_at timestamptz NOT NULL
);

CREATE TABLE offers (
    offer_code varchar(20) PRIMARY KEY,
    description varchar(120) NOT NULL,
    discount_pct numeric(5,2) NOT NULL CHECK (discount_pct BETWEEN 0 AND 100),
    max_discount numeric(8,2) NOT NULL CHECK (max_discount >= 0),
    valid_from date NOT NULL,
    valid_to date NOT NULL,
    CHECK (valid_to >= valid_from)
);

CREATE TABLE bookings (
    booking_id integer PRIMARY KEY,
    booking_code char(10) NOT NULL UNIQUE CHECK (booking_code ~ '^BMS[0-9A-F]{7}$'),
    customer_id integer NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    show_id integer NOT NULL REFERENCES shows(show_id) ON DELETE RESTRICT,
    booked_at timestamptz NOT NULL,
    num_tickets smallint NOT NULL CHECK (num_tickets BETWEEN 1 AND 10),
    ticket_amount numeric(10,2) NOT NULL CHECK (ticket_amount >= 0),
    convenience_fee numeric(8,2) NOT NULL CHECK (convenience_fee >= 0),
    fnb_amount numeric(8,2) NOT NULL CHECK (fnb_amount >= 0),
    offer_code varchar(20) REFERENCES offers(offer_code) ON DELETE RESTRICT,
    discount numeric(8,2) NOT NULL CHECK (discount >= 0),
    total_amount numeric(10,2) NOT NULL CHECK (total_amount >= 0),
    payment_method varchar(12) NOT NULL CHECK (payment_method IN ('UPI','CARD','GIFT_CARD','WALLET','NETBANKING')),
    status varchar(16) NOT NULL CHECK (status IN ('PENDING','CONFIRMED','CANCELLED','PAYMENT_FAILED')),
    CHECK (convenience_fee = round(ticket_amount * 0.10, 2)),
    CHECK (discount <= ticket_amount + convenience_fee + fnb_amount),
    CHECK (total_amount = ticket_amount + convenience_fee + fnb_amount - discount)
);

CREATE TABLE booking_seats (
    booking_id integer NOT NULL REFERENCES bookings(booking_id) ON DELETE CASCADE,
    show_id integer NOT NULL REFERENCES shows(show_id) ON DELETE RESTRICT,
    seat_id integer NOT NULL REFERENCES seats(seat_id) ON DELETE RESTRICT,
    price numeric(8,2) NOT NULL CHECK (price >= 0),
    PRIMARY KEY (show_id, seat_id)
);

CREATE TABLE movie_reviews (
    review_id integer PRIMARY KEY,
    movie_id integer NOT NULL REFERENCES movies(movie_id) ON DELETE RESTRICT,
    customer_id integer NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    rating smallint NOT NULL CHECK (rating BETWEEN 1 AND 10),
    review_text text,
    created_at timestamptz NOT NULL
);