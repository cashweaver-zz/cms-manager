# CMS Manager
Version: 1.1

A CMS-agnostic aproach to managing your hosted websites.

**Drupal** and **WordPress** (running on **MySQL**) are currently supported.

----------

## Commands

**backup**: Backup the files and database for a given website.

**clone**: Clone existing website.

**destroy**: Remove files, database, and database user for a given website.

**new**: Create a new instance of a CMS

**status**: Check a given website for available updates.

**restore**: Restore a website.

**update**: Update a given website.

### Under Development

list (1.1): Display list of all hosted websites.

test (1.X): Run tests on a given website. Options define which test(s) are run.

----------

## Installation

### For everyone

1. Download the latest release
2. `$ ln -s cms-manager /usr/bin/cms-manager`

### Just for me

1. Download the latest release
2. `$ ln -s cms-manager /usr/local/bin/cms-manager`
