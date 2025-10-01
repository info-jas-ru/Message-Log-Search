package MyApp;
use Mojo::Base 'Mojolicious';

sub startup {
    my $self = shift;
    
    require MyApp::Model::LogSearch;
    require MyApp::Controller::LogSearch;
    require MyApp::Utils;
    
    # Загрузка конфигурации
    my $app_dir = $self->home;
    $self->plugin('Config' => {
        file    => $app_dir->child('config', 'my_app.conf'),
        default => {
            secrets => ['fallback_secret'],
            log_level => 'debug',
            database => {
                driver => 'mysql',
                host => 'localhost',
                database => 'message_log_app'
            },
            search => {
                max_results => 100
            }
        }
    });
    
    $self->renderer->paths([$app_dir->child('templates')]);
    $self->static->paths([$app_dir->child('public')]);
    
    $self->helper(log_search => sub {
        my $c = shift;
        state $search = MyApp::Model::LogSearch->new(app => $self);
        return $search;
    });
    
    # Router
    my $r = $self->routes;

    $r->get('/')->to('log_search#search_form')->name('search_form');
    $r->post('/search')->to('log_search#search_results')->name('search_results');
}

1;