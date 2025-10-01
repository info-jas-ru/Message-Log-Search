package MyApp::Controller::LogSearch;
use Mojo::Base 'Mojolicious::Controller';
use MyApp::Utils qw(format_date);

sub search_form {
    my $c = shift;
    
    $c->render(
        title => 'Поиск логов по адресу',
        address => '',
        results => [],
        search_performed => 0,
        error => undef,
        total_found => 0,
        has_more => 0,
        limit => 100
    );
}

sub search_results {
    my $c = shift;
    
    my $address = $c->param('address') || '';
    my $limit = $c->app->config->{search}{max_results} || 100;
    
    $c->app->log->debug("Search request for address: $address");
    
    unless ($address) {
        return $c->render(
            template => 'log_search/search_form',
            title => 'Поиск логов по адресу',
            address => '',
            results => [],
            search_performed => 1,
            error => 'Пожалуйста, введите адрес для поиска',
            total_found => 0,
            has_more => 0,
            limit => $limit
        );
    }

    eval {
        my $search_result = $c->app->log_search->search_logs_by_address($address, $limit);
        
        $c->render(
            template => 'log_search/search_form',
            title => 'Результаты поиска',
            address => $address,
            results => $search_result->{results},
            search_performed => 1,
            total_found => $search_result->{total_found},
            has_more => $search_result->{has_more},
            limit => $search_result->{limit},
            error => undef
        );
    };
    
    if ($@) {
        $c->app->log->error("Search error: $@");
        $c->render(
            template => 'log_search/search_form',
            title => 'Ошибка поиска',
            address => $address,
            results => [],
            search_performed => 1,
            error => "Ошибка при поиске: $@",
            total_found => 0,
            has_more => 0,
            limit => $limit
        );
    }
}

1;