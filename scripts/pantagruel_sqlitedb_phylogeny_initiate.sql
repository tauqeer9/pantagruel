-- reference tree

CREATE TABLE   species_tree (
  branch_id INT PRIMARY KEY,
  parent_branch_id INT,
  branch_name VARCHAR(50) DEFAULT NULL,   -- only for tips and clade/populationancestors
  is_tip BOOL 
);

CREATE TABLE   species_tree_events (
  event_id INT PRIMARY KEY,
  event_type char(1) NOT NULL,
  don_branch_id INT,          -- refers to species_tree (branch_id)
  rec_branch_id INT NOT NULL  -- refers to species_tree (branch_id)
);

CREATE INDEX ON species_tree_events (event_type);
CREATE INDEX ON species_tree_events (don_branch_id);
CREATE INDEX ON species_tree_events (rec_branch_id);

CREATE TABLE gene_lineage_events ( --to be a large table
  event_id SERIAL,
  cds_code VARCHAR(50) NOT NULL,             -- refers to genome.coding_sequences (cds_code)
  freq INT NOT NULL,
  reconciliation_id INT DEFAULT NULL    -- to distinguish reconciliation sets; can be NULL if not to be redundant
);

CREATE TABLE reconciliation_collections (
  reconciliation_id INT NOT NULL,
  reconciliation_name VARCHAR NOT NULL,
  software VARCHAR NOT NULL,
  version VARCHAR NOT NULL,
  algorithm VARCHAR,
  reconciliation_date TIMESTAMP,
  notes TEXT
);

-- gene trees

CREATE TABLE criteria_collapse_gene_tree_clades (
  criterion_id INT PRIMARY KEY,
  criterion_name VARCHAR(50) NOT NULL,
  criterion_definition TEXT,
  collapsed_clade_collection_creation DATE
);

CREATE TABLE collapsed_gene_tree_clades (
  gene_family_id VARCHAR(20) NOT NULL,
  col_clade VARCHAR(10) NOT NULL,
  cds_code VARCHAR(20) NOT NULL,
  collapse_criterion_id INT DEFAULT NULL
);

CREATE TABLE criteria_replace_gene_tree_clades (
  criterion_id INT PRIMARY KEY,
  criterion_name VARCHAR(50) NOT NULL,
  criterion_definition TEXT,
  replaced_clade_collection_creation DATE
);

CREATE TABLE replaced_gene_tree_clades (
  gene_family_id VARCHAR(20) NOT NULL,
  col_clade_or_cds_code VARCHAR(20) NOT NULL,
  replacement_label VARCHAR(60) DEFAULT NULL,
  replace_criterion_id INT DEFAULT NULL
);
