# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SIGA (Sistema Integrado de Gestión Académica) is a web application built with Rails 7.0.10, Ruby 3.1.2, and PostgreSQL. The project is in early development stage. Project documentation and ER diagrams are in `docs owns/`.

## Common Commands

```bash
# Setup
bin/setup                          # Initial project setup
bin/rails db:create db:migrate     # Create and migrate database

# Development
bin/rails server                   # Start dev server (localhost:3000)
bin/rails console                  # Rails console

# Database
bin/rails db:migrate               # Run pending migrations
bin/rails db:rollback              # Rollback last migration
bin/rails db:seed                  # Seed database

# Tests
bin/rails test                     # Run all tests
bin/rails test test/models/        # Run model tests
bin/rails test test/models/user_test.rb        # Run single test file
bin/rails test test/models/user_test.rb:10     # Run single test by line

# Generators
bin/rails generate model Name field:type       # Generate model with migration
bin/rails generate controller Name action      # Generate controller
```

## Architecture

- **Ruby 3.1.2 / Rails 7.0.10** with PostgreSQL (`siga_development` / `siga_test` databases)
- **Views**: Haml (`.html.haml`) — not ERB. All views and Devise templates use Haml.
- **Frontend**: Hotwire (Turbo + Stimulus) with Importmap (no Node.js/Webpack)
- **Authentication**: Devise on `User` model. `ApplicationController` enforces `authenticate_user!` globally — new controllers must `skip_before_action` for public pages.
- **Routing**: Root points to `inicio#index`. Devise routes at `/users/sign_in`, `/users/sign_up`, etc.
- **Module name**: `Siga` (see `config/application.rb`)

## Conventions

- Views must be written in **Haml**, not ERB
- Spanish is used for controller/view naming (e.g., `InicioController`, not `HomeController`)
- All routes require authentication by default; explicitly skip for public endpoints
