-- ids:
--  id: bigserial
--  idx: bytea # 16 bytes, indexed, used for lookup
--  remainder: bytea # remainder of binary data
--  type: smallint # 0=eoa 1=contract 2=txhash 3=blockhash
-- TAMCHAU:
--   "type" is postgres internal key, should use other name -> "id_type".
--   Should ENUM instead of smallint for better performance (don't need to convert int to value later).
--   Consider to add "created_at" column (maybe index for it also) in this table to track when a new
--     record is created.
--   Consider to add unique (might be partial) index on remainder to make sure no duplication txs,
--      at least for txhash, contract...
CREATE TYPE id_type AS ENUM ('eoa', 'contract', 'txhash', 'blockhash');
CREATE TABLE ids (
   id bigserial PRIMARY KEY, -- idx index created automatically for primary key (ids_pkey)
   remainder bytea NOT NULL,
   id_type id_type NOT NULL,
   created_at int NOT NULL
);

-- nicks:
--  id: bigint # foreign key id@ids
--  nick: string # nickname of the particular id
--  type: smallint # indicates nickname type
-- TAMCHAU:
--   String type should be converted to "varchar" with maximum is 255 chars.
--   Changes the name of column to "nick_type".
--   If the type is limited, we should consider to use `enum` as above.
--   According to the filter function later, we should add index for nick or nick_type if needed.
CREATE TABLE nicks (
    id bigint NOT NULL,
    nick varchar(255) NOT NULL,
    nick_type smallint NOT NULL,
    CONSTRAINT ids_nick_fk
        FOREIGN KEY(id)
	    REFERENCES ids(id)
);

-- erc20tokens:
--  id: bigint # foreign key id@ids
--  name: string # token name
--  symbol: string # token symbol
--  decimals: smallint # how many decimals the token has
--  supply: bigint # divided by decimals
-- TAMCHAU:
--   "name" is internal key -> "token_name".
--    Symbol should have maximum 100 chars.
--    According to the filter function later, we should add index for symbol if needed.

CREATE TABLE erc20tokens (
    id bigint NOT NULL,
    token_name varchar(255) NOT NULL,
    symbol varchar(100) NOT NULL,
    decimals smallint NOT NULL,
    supply bigint NOT NULL,
    CONSTRAINT ids_erc20token_fk
        FOREIGN KEY(id)
	    REFERENCES ids(id)
);

-- blocks:
--   id: bigint # foreign key id@ids, the blockhash
--   height: int # block height in the chain
--   created_at: int # unix ts
-- TAMCHAU:
--   We can get rid "created_at" column here since it's present in ids table.
--   "height" column is referenced from txs table, so we should add index for it.
CREATE TABLE blocks (
    id bigint NOT NULL,
    height int NOT NULL,
    CONSTRAINT ids_block_fk
        FOREIGN KEY(id)
	    REFERENCES ids(id)
);
CREATE INDEX index_blocks_on_height ON blocks (height); -- Should be UNIQUE?

-- txs:
--  txhash: bigint # foreign key id@ids, the txhash
--  block: int # block height, foreign key height@blocks
--  value: bigint # in gwei
--  from_id: bigint # foreign key id@ids
--  to_id: bigint # foreign key id@ids
--  gas_limit: bigint
--  gas_price: bigint
--  method_id: int? # 4 bytes
--  params: bytea? # not contract deployment, not erc20
-- TAMCHAU:
--  "txhash" is changed to "txhash_id" for more clear.
--  "block" is changed to "block_height" for more clear.
--  "value" should be changed to "tx_value" since value is PG internal key.
--  Consider to get rid of blocks table and move "height" & "created_at" columns into this table
--    in order to improve query performance & save resource (disk memory).
CREATE TABLE txs (
    txhash_id bigint NOT NULL,
    block_height int NOT NULL,
    tx_value bigint NOT NULL,
    from_id bigint NOT NULL,
    to_id bigint NOT NULL,
    gas_limit bigint NOT NULL,
    gas_price bigint NOT NULL,
    method_id int,
    params int,

    CONSTRAINT ids_txs_txhash_id_fk
        FOREIGN KEY(txhash_id)
	    REFERENCES ids(id),
    CONSTRAINT ids_txs_from_id_fk
        FOREIGN KEY(from_id)
	    REFERENCES ids(id),
    CONSTRAINT ids_txs_to_id_fk
        FOREIGN KEY(to_id)
	    REFERENCES ids(id)
);

-- ethtxs: # if data == 0x tx gets inserted
--  txhash: bigint # foreign key id@ids
--  from_id: bigint # foreign key id@ids
--  to_id: bigint # foreign key id@ids
--  value: bigint # in gwei
CREATE TABLE ethtxs (
    txhash_id bigint NOT NULL,
    tx_value bigint NOT NULL,
    from_id bigint NOT NULL,
    to_id bigint NOT NULL,

    CONSTRAINT ids_txs_txhash_id_fk
        FOREIGN KEY(txhash_id)
	    REFERENCES ids(id),
    CONSTRAINT ids_txs_from_id_fk
        FOREIGN KEY(from_id)
	    REFERENCES ids(id),
    CONSTRAINT ids_txs_to_id_fk
        FOREIGN KEY(to_id)
	    REFERENCES ids(id)
);


-- erc20txs: # if first four bytes indicate transfer
-- signature tx gets inserted
--  txhash: bigint # foreign key id@ids
--  token_id: bigint # foreign key id@ids
--  from_id: bigint # foreign key id@ids
--  to_id: bigint # foreign key id@ids
--  value: bigint # divided by decimals
CREATE TABLE erc20txs (
    txhash_id bigint NOT NULL,
    tx_value bigint NOT NULL,
    from_id bigint NOT NULL,
    to_id bigint NOT NULL,
    token_id bigint NOT NULL,

    CONSTRAINT ids_txs_txhash_id_fk
        FOREIGN KEY(txhash_id)
	    REFERENCES ids(id),
    CONSTRAINT ids_txs_from_id_fk
        FOREIGN KEY(from_id)
	    REFERENCES ids(id),
    CONSTRAINT ids_txs_to_id_fk
        FOREIGN KEY(to_id)
	    REFERENCES ids(id),
    CONSTRAINT ids_txs_token_id_fk
        FOREIGN KEY(token_id)
	    REFERENCES ids(id)
);

-- contracts:
--  txhash: bigint # foreign key id@ids
--  address_id: bigint # contract address, foreign key id@ids
--  deployer_id: bigint # deployer address, foreign key id@ids
--  bytecode: bytea # contract bytecode
CREATE TABLE contracts (
    txhash_id bigint NOT NULL,
    address_id bigint NOT NULL,
    deployer_id bigint NOT NULL,
    bytecode bytea NOT NULL,

    CONSTRAINT ids_txs_txhash_id_fk
        FOREIGN KEY(txhash_id)
	    REFERENCES ids(id),
    CONSTRAINT ids_txs_address_id_fk
        FOREIGN KEY(address_id)
	    REFERENCES ids(id),
    CONSTRAINT ids_txs_deployer_id_fk
        FOREIGN KEY(deployer_id)
	    REFERENCES ids(id)
);

-- stats:
--  address_id: bigint # foreign key id@ids
--  token_id: bigint # foreign key id@ids, or 0 for eth
-- transfers
--  balance: bigint # divided by decimals / gwei
--  first_in: int # unix ts
--  first_out: int # unix ts
--  last_in: int # unix ts
--  last_out: int # unix ts
CREATE TABLE stats (
    address_id bigint NOT NULL,
    token_id bigint NOT NULL,
    balance bigint NOT NULL,
    first_in int NOT NULL,
    first_out int NOT NULL,
    last_in int NOT NULL,
    last_out int NOT NULL,

    CONSTRAINT ids_txs_address_id_fk
        FOREIGN KEY(address_id)
	    REFERENCES ids(id),
    CONSTRAINT ids_txs_token_id_fk
        FOREIGN KEY(token_id)
	    REFERENCES ids(id)
);
