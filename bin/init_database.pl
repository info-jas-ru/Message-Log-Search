#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Mojo::File;

# Загрузка конфигурации из my_app.conf
my $config_file = Mojo::File->new($FindBin::Bin, '..', 'config', 'my_app.conf');
my $config = load_config($config_file);

# Подключение к MySQL
my $db_config = $config->{database};
my $dsn = "DBI:mysql:host=$db_config->{host};port=$db_config->{port}";
my $dbh = DBI->connect($dsn, $db_config->{username}, $db_config->{password}) 
    or die "Cannot connect to MySQL: " . DBI->errstr;

# Подготовка SQL запросов
print "Prepare queries...\n";
my $insert_message = $dbh->prepare("INSERT INTO message (created, id, int_id, str, status) VALUES (?, ?, ?, ?, ?)");
my $insert_log = $dbh->prepare("INSERT INTO log (created, int_id, str, address) VALUES (?, ?, ?, ?)");

# Файл лога
my $log_file = $config->{log_file};
print "Log file ".$log_file."...\n";

# Создание базы данных
print "Creating database '$db_config->{database}'...\n";
$dbh->do("CREATE DATABASE IF NOT EXISTS $db_config->{database} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
$dbh->do("USE $db_config->{database}");

print "Deleting tables...\n";

$dbh->do("
    DROP TABLE IF EXISTS message
");

$dbh->do("
    DROP TABLE IF EXISTS log
");

print "Creating tables...\n";

$dbh->do("
    CREATE TABLE IF NOT EXISTS message (
        `created` TIMESTAMP(0) NOT NULL,
        `id` VARCHAR(16) NOT NULL,
        `int_id` CHAR(16) NOT NULL,
        `str` VARCHAR(256) NOT NULL,
        `status` BOOL,
        CONSTRAINT message_id_pk PRIMARY KEY(id)
    );
");

$dbh->do("
    CREATE INDEX message_created_idx ON message (created)
");

$dbh->do("
    CREATE INDEX message_int_id_idx ON message (int_id)
");

$dbh->do("
    CREATE TABLE log (
        created TIMESTAMP(6),
        int_id CHAR(16) NOT NULL,
        str VARCHAR(1024),
        address VARCHAR(256)
    )
");

$dbh->do("
    CREATE INDEX log_address_idx ON log (address) USING HASH
");

# Начальные данные
print "Inserting initial data...\n";

open(my $fh, '<', $log_file) or die "I can't open the file $log_file: $!";

while (my $line = <$fh>) {
    chomp $line;

    next if $line =~ /^\s*$/;
    
    if ($line =~ /^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})\s+(\S+)\s+(.+)$/) {
        my $date = $1;
        my $time = $2;
        my $int_id = $3;
        my $rest = $4;

        my $created = "$date $time";
        
        if ($rest =~ /^<=\s+(\S+)/) {
            my $address = $1;
            
            my $message_id = "";
            if ($rest =~ /id=([^\s]+)/) {
                $message_id = $1;
            
                if (length($message_id) > 16) {
                    $message_id = substr($message_id, 0, 16);
                }
            }
            
            if ($message_id eq "") {
                $message_id = substr($int_id, 0, 16);
            }
            
            my $short_int_id = substr($int_id, 0, 16);
            my $short_str = substr($rest, 0, 256);
            
            print "Found message: int_id=$short_int_id, message_id=$message_id\n";
            $insert_message->execute($created, $message_id, $short_int_id, $short_str, undef);
            
        } else {
            my $address = "";
            my $status = undef;
            
            my $flag = "";
            
            if ($rest =~ /^(=>|->|\*\*|==)\s+(.+?)\s+(R=|$)/) {
                $flag = $1;
                my $potential_address = $2;
                
                if ($potential_address =~ /<([^>]+)>/) {
                    $address = $1;
                } elsif ($potential_address =~ /^:([^:]+):$/) {
                    $address = $1;
                } elsif ($potential_address =~ /^(\S+@\S+)$/) {
                    $address = $1;
                } else {
                    $address = (split(/\s+/, $potential_address))[0];
                }
            } elsif ($rest =~ /^(\S+)\s+(=>|->|\*\*|==)\s+(.+?)\s+(R=|$)/) {
                $flag = $2;
                my $potential_address = $3;
                
                if ($potential_address =~ /<([^>]+)>/) {
                    $address = $1;
                } elsif ($potential_address =~ /^:([^:]+):$/) {
                    $address = $1;
                } elsif ($potential_address =~ /^(\S+@\S+)$/) {
                    $address = $1;
                } else {
                    $address = (split(/\s+/, $potential_address))[0];
                }
            }
            
            if ($flag eq '=>' || $flag eq '->') {
                $status = 1;
            } elsif ($flag eq '**' || $flag eq '==') {
                $status = 0;
            }
            
            my $short_int_id = substr($int_id, 0, 16);
            my $short_str = substr($rest, 0, 1024);
            my $short_address = substr($address, 0, 256);
            
            $insert_log->execute($created, $short_int_id, $short_str, $short_address);
            
            if (defined $status) {
                eval {
                    my $update_status = $dbh->prepare("UPDATE message SET status = ? WHERE int_id = ?");
                    $update_status->execute($status, $short_int_id);
                    $update_status->finish();
                };
                if ($@) {
                    print "Warning: Could not update status for int_id=$short_int_id: $@\n";
                }
            }
            
            if ($address) {
                print "Parsed: flag=$flag, address=$address\n";
            }
        }
    } else {
        print "Cannot parse: $line\n";
    }
}

close($fh);

# Фиксируем изменения в БД
$dbh->commit();

# Закрываем подготовленные запросы и соединение
$insert_message->finish();
$insert_log->finish();

print "Database '$db_config->{database}' initialized successfully!\n";

# Проверяем созданные таблицы
my $tables = $dbh->selectall_arrayref("SHOW TABLES");
print "\nCreated tables:\n";
foreach my $table (@$tables) {
    print " - $table->[0]\n";
}

$dbh->disconnect;

# Функция загрузки конфигурации
sub load_config {
    my $config_file = shift;
    
    unless (-e $config_file) {
        die "Config file not found: $config_file\n";
    }
    
    my $content = $config_file->slurp;
    
    # Простой парсинг Perl-структуры
    my $config = eval $content;
    if ($@) {
        die "Error parsing config file: $@\n";
    }
    
    return $config;
}