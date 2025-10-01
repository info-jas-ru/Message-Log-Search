package MyApp::Model::LogSearch;
use Mojo::Base -base;
use DBI;
use MyApp::Utils qw(ceil format_date format_datetime truncate_string);

has 'app';

sub search_logs_by_address {
    my ($self, $address, $limit) = @_;
    
    my $dbh = $self->get_dbh;
    $limit ||= 100;
    
    my $sql = "
        SELECT 
            l.created as log_created,
            l.int_id,
            l.str as log_message,
            l.address,
            m.created as msg_created,
            m.str as msg_content,
            m.status
        FROM log l
        LEFT JOIN message m ON l.int_id = m.int_id
        WHERE l.address LIKE ?
        ORDER BY l.int_id, l.created
        LIMIT ?
    ";
    
    my $sth = $dbh->prepare($sql);
    $sth->execute("%$address%", $limit + 1);
    
    my @results;
    my $count = 0;
    my $has_more = 0;
    
    while (my $row = $sth->fetchrow_hashref) {
        $count++;
        if ($count > $limit) {
            $has_more = 1;
            last;
        }

        if ($row->{log_created}) {
            $row->{log_created_formatted} = MyApp::Utils::format_datetime($row->{log_created});
        }
        if ($row->{msg_created}) {
            $row->{msg_created_formatted} = MyApp::Utils::format_datetime($row->{msg_created});
        }

        $row->{status_text} = $self->_get_status_text($row->{status});
        $row->{status_class} = $self->_get_status_class($row->{status});
        
        push @results, $row;
    }
    
    return {
        results => \@results,
        total_found => $count,
        has_more => $has_more,
        limit => $limit
    };
}

sub _get_status_text {
    my ($self, $status) = @_;
    
    if (!defined $status) {
        return 'Неизвестно';
    } elsif ($status == 1) {
        return 'Доставлено';
    } elsif ($status == 0) {
        return 'Не доставлено';
    } else {
        return 'Неизвестный статус';
    }
}

sub _get_status_class {
    my ($self, $status) = @_;
    
    if (!defined $status) {
        return 'status-unknown';
    } elsif ($status == 1) {
        return 'status-delivered';
    } elsif ($status == 0) {
        return 'status-failed';
    } else {
        return 'status-unknown';
    }
}

sub get_dbh {
    my $self = shift;
    
    my $config = $self->app->config->{database};
    my $dsn = "DBI:mysql:database=$config->{database};host=$config->{host};port=$config->{port}";
    
    return DBI->connect(
        $dsn,
        $config->{username},
        $config->{password},
        $config->{options}
    ) or die "Cannot connect to database: " . DBI->errstr;
}

1;