<?php
$parameters = array(
    // Configurações do Banco de Dados
    'db_driver' => 'pdo_mysql',
    'db_host' => getenv('MAUTIC_DB_HOST'),
    'db_port' => getenv('MAUTIC_DB_PORT') ?: 3306,
    'db_name' => getenv('MAUTIC_DB_NAME'),
    'db_user' => getenv('MAUTIC_DB_USER'),
    'db_password' => getenv('MAUTIC_DB_PASSWORD'),
    'db_table_prefix' => getenv('MAUTIC_DB_PREFIX') ?: null,
    'db_backup_tables' => false,
    'db_backup_prefix' => 'bak_',

    // Configurações do Site
    'site_url' => getenv('MAUTIC_URL'),
    'image_path' => 'media/images',
    'tmp_path' => '/tmp',
    'theme' => getenv('MAUTIC_THEME') ?: 'blank',

    // Configurações de Email
    'mailer_from_name' => getenv('MAUTIC_MAILER_FROM_NAME'),
    'mailer_from_email' => getenv('MAUTIC_MAILER_FROM_EMAIL'),
    'mailer_transport' => getenv('MAUTIC_MAILER_TRANSPORT'),
    'mailer_host' => getenv('MAUTIC_MAILER_HOST'),
    'mailer_port' => getenv('MAUTIC_MAILER_PORT'),
    'mailer_user' => getenv('MAUTIC_MAILER_USER'),
    'mailer_password' => getenv('MAUTIC_MAILER_PASSWORD'),
    'mailer_encryption' => getenv('MAUTIC_MAILER_ENCRYPTION'),
    'mailer_auth_mode' => getenv('MAUTIC_MAILER_AUTH_MODE'),
    'mailer_spool_type' => getenv('MAUTIC_MAILER_SPOOL_TYPE') ?: 'file',
    'mailer_spool_path' => getenv('MAUTIC_MAILER_SPOOL_PATH') ?: '%kernel.root_dir%/spool',

    // Configurações do Admin
    'admin_email' => getenv('MAUTIC_ADMIN_EMAIL'),
    'admin_password' => getenv('MAUTIC_ADMIN_PASSWORD'),
    'admin_firstname' => getenv('MAUTIC_ADMIN_FIRSTNAME'),
    'admin_lastname' => getenv('MAUTIC_ADMIN_LASTNAME'),

    // Configurações de Segurança
    'secret_key' => getenv('MAUTIC_SECRET_KEY') ?: 'def00000fc1e34ca0f47d0c99c19768c551b451a956c9f83d308cca6b09518bb5204d51ff5fca14f',
    'rememberme_key' => getenv('MAUTIC_REMEMBERME_KEY') ?: 'def00000a1f254e2975677d5d2c18a119be4c6c834a8b5c5e3d654f2d8d9c5d2',
    'rememberme_lifetime' => 31536000,
    'rememberme_path' => '/',
    'rememberme_domain' => '',

    // Configurações Regionais
    'locale' => getenv('MAUTIC_LOCALE') ?: 'pt_BR',
    'timezone' => getenv('MAUTIC_TIMEZONE') ?: 'America/Sao_Paulo',

    // Flags de Instalação
    'installed' => true,
    'is_installed' => true,
    'db_installed' => true,
    'install_source' => 'docker'
); 