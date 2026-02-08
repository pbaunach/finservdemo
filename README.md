# Finserv Demo

Rails application (upgraded to **Rails 7.2** and **Ruby 3.x**).

## Requirements

- **Ruby 3.0+** (tested with Ruby 3.4)
- **Bundler** (gem install bundler)

## Setup

```bash
cd "c:\Cursor Apps\finservdemo"
bundle install
bundle exec rake db:create
```

## Run locally

```bash
bundle exec rails server
```

Then open **http://localhost:3000**.

If port 3000 is in use or blocked, use another port:

```bash
bundle exec rails server -p 3001
```

Then open **http://localhost:3001**.

## Routes

- `/` – welcome#index
- `/mc/journey`, `/mobile/demo`, `/mobile/ipad`, `/mobile/ins`
- `/ins/community`, `/today/today`, `/wm/bob`, `/wm/profile`
- `/sales/leadlist`, `/cb/profile`

## Tech stack

- Rails 7.2.3
- Ruby 3.x
- SQLite3
- jQuery, Turbolinks, SASS, CoffeeScript
