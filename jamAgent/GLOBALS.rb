# VARIOUS GLOBAL CONSTANTS
$host = 'localhost'
$port = 12345
$PARENT_DIR = __FILE__[0..File.dirname(__FILE__).chop.rindex('/')]

#puts $PARENT_DIR
#$LOAD_PATH << $PARENT_DIR

#####################################################################################################
########################## DEFAULT INTERVALS FOR GENRATING RANDOM DATA IN AGENTS! ###################
#####################################################################################################

# Agent startup delay in seconds
$agent_start_delay_min = 1.0
$agent_start_delay_max = 560.0

# sleep time between rounds\iterations in seconds. SHOULD BE FLOAT TYPE !
$sleep_time_min = 7.0
$sleep_time_max = 35.0

# Maximum number of rounds\iterations of idle beheaviour
$max_idle_min = 3
$max_idle_max = 10

# Price drop coefficent * 100% = price drop % 
# Used for determining which stocks should agent 
$coef_price_decrease_min = -0.15
$coef_price_decrease_max = -0.01

# Price rise coefficent * 100% = price drop % 
# Used for determining which stocks should agent buy 
$coef_price_increase_min = 0.01
$coef_price_increase_max = 0.15

# this * 100% = % of money agent will use when buying stocks
$coef_money_when_buying_min = 0.05
$coef_money_when_buying_max = 1.0

# this * 100% = % of a given stocks agent will be selling
$coef_orders_when_selling_min = 0.05
$coef_orders_when_selling_max = 1.0

# Max count of subscribed stocks.
$subscribed_count_min = 3
$subscribed_count_max = 7

# Maximal amount of orders an agent can hold in a given moment.
$max_orders_treshold_min = 2
$max_orders_treshold_max = 15

# Used generate random price_per_stock 
# when there's no data about price per stock for a given stock (No BestOrder). 
$random_price_per_stock_when_selling_min = 10
$random_price_per_stock_when_selling_max = 10000

# Maximal amount of sell orders to be ordered in one round\iteration
# If there are many order agent choose max_buy_candidates stocks randomly.
$max_buy_candidates_min = 1
$max_buy_candidates_max = 3

# Maximal amount of sell orders to be ordered in one round\iteration
# If there are many order agent choose max_sell_candidates stocks randomly.
$max_sell_candidates_min = 1
$max_sell_candidates_max = 3

# try % times read a packet. After a fail agent sleeps for a second and tries again.
$reading_packet_trials = 3

# Time in seconds before select gives up waiting for a socket to become active (for reading).
$timeout_for_select = 20

# 
$reconnect_trials = 2
