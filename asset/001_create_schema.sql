-- 001_create_schema.sql
-- PostgreSQL schema for the auction app (MVP)

CREATE EXTENSION IF NOT EXISTS "uuid-ossp"; -- optional UUID support

-- ==============================================================
-- 1. users table
-- ==============================================================
CREATE TABLE users (
    id            BIGINT PRIMARY KEY,
    name          VARCHAR(255) NOT NULL,
    email         VARCHAR(255) NOT NULL UNIQUE,
    avatar_url    VARCHAR(512),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================
-- 2. categories table
-- ==============================================================
CREATE TABLE categories (
    id            BIGINT PRIMARY KEY,
    name          VARCHAR(255) NOT NULL,
    icon_url      VARCHAR(512),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================
-- 3. items table
-- ==============================================================
CREATE TABLE items (
    id            BIGINT PRIMARY KEY,
    name          VARCHAR(255) NOT NULL,
    description   TEXT,
    image_url     VARCHAR(512),
    price         BIGINT NOT NULL,               -- VND
    category_id   BIGINT REFERENCES categories(id) ON DELETE SET NULL,
    owner_id      BIGINT REFERENCES users(id) ON DELETE CASCADE,
    status        VARCHAR(20) NOT NULL DEFAULT 'available',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================
-- 4. auction_sessions table
-- ==============================================================
CREATE TABLE auction_sessions (
    id                 BIGINT PRIMARY KEY,
    item_id            BIGINT REFERENCES items(id) ON DELETE CASCADE,
    seller_id          BIGINT REFERENCES users(id) ON DELETE CASCADE,
    starting_price     BIGINT NOT NULL,            -- VND
    current_highest_bid BIGINT NOT NULL DEFAULT 0,
    highest_bidder_id  BIGINT REFERENCES users(id),
    status             VARCHAR(20) NOT NULL DEFAULT 'scheduled',
    start_time         TIMESTAMPTZ,
    end_time           TIMESTAMPTZ,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_status CHECK (status IN ('scheduled', 'active', 'ended', 'cancelled'))
);

-- Index for quickly finding active sessions
CREATE INDEX idx_auction_sessions_active ON auction_sessions (status) WHERE status = 'active';

-- ==============================================================
-- 5. bids table
-- ==============================================================
CREATE TABLE bids (
    id            BIGINT PRIMARY KEY,
    session_id    BIGINT REFERENCES auction_sessions(id) ON DELETE CASCADE,
    user_id       BIGINT REFERENCES users(id) ON DELETE CASCADE,
    amount        BIGINT NOT NULL,               -- VND
    bid_time      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for bid history per session (most recent first)
CREATE INDEX idx_bids_session ON bids (session_id, bid_time DESC);

-- Optional: transactions and notifications tables (can be omitted)
CREATE TABLE transactions (
    id            BIGINT PRIMARY KEY,
    user_id       BIGINT REFERENCES users(id) ON DELETE CASCADE,
    amount        BIGINT NOT NULL,               -- VND
    type          VARCHAR(20) NOT NULL,          -- e.g. 'deposit', 'withdraw'
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE notifications (
    id            BIGINT PRIMARY KEY,
    user_id       BIGINT REFERENCES users(id) ON DELETE CASCADE,
    title         VARCHAR(255) NOT NULL,
    body          TEXT NOT NULL,
    is_read       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- End of schema
