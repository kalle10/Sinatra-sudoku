require 'sinatra'
require 'sinatra/partial'
require 'rack-flash'
require_relative './lib/sudoku'
require_relative './lib/cell'
require_relative './helpers/application'

enable :sessions
set :partial_template_engine, :erb
set :session_secret, "I'm the secret key to sign the cookie"
use Rack::Flash

configure :production do
  require 'newrelic_rpm'
end

def random_sudoku
  seed = (1..9).to_a.shuffle + Array.new(81-9, 0)
  sudoku = Sudoku.new(seed.join)
  sudoku.solve!
  sudoku.to_s.chars
  #'615493872348127956279568431496832517521746389783915264952681743864379125137254698'
end

def puzzle(sudoku)
  # 64.times{puzzle[rand(81)] = 0}
  sudoku = random_sudoku
  indices = (1..81).to_a.sample(40)
  indices.each do |index|
    sudoku[index] = ''
  end
  sudoku
end

def hard_puzzle(sudoku)
  sudoku = random_sudoku
  indices = (1..81).to_a.sample(75)
  indices.each do |index|
    sudoku[index] = ''
  end
  sudoku
end

def new_puzzle
  sudoku = random_sudoku
  session[:solution] = sudoku
  session[:puzzle] = puzzle(sudoku)
  session[:current_solution] = session[:puzzle]
end

def new_hard_puzzle
  sudoku = random_sudoku
  session[:solution] = sudoku
  session[:puzzle] = hard_puzzle(sudoku)
  session[:current_solution] = session[:puzzle]
end

def generate_new_puzzle_if_necessary
  return if session[:current_solution]
  sudoku = random_sudoku
  session[:solution] = sudoku
  session[:puzzle] = puzzle(sudoku)
  session[:current_solution] = session[:puzzle]
end

def prepare_to_check_solution
  @check_solution = session[:check_solution]
  if @check_solution
    flash[:notice] = "Incorrect values are highlighted"
  end
  session[:check_solution] = nil
end

def box_order_to_row_order(cells)
  boxes = cells.each_slice(9).to_a
  (0..8).to_a.inject([]) { |memo, i|
    first_box_index = i / 3 * 3
    three_boxes = boxes[first_box_index, 3]
    three_rows_of_three = three_boxes.map do |box|
      row_number_in_a_box = i % 3
      first_cell_in_the_row_index = row_number_in_a_box * 3
      box[first_cell_in_the_row_index, 3]
    end
    memo+= three_rows_of_three.flatten
  }
end

not_found do
  status 404
  'Page not found!'
end

get '/' do
  prepare_to_check_solution
  generate_new_puzzle_if_necessary
  @current_solution = session[:current_solution] || session[:puzzle]
  @solution = session[:solution]
  @puzzle = session[:puzzle]
  erb :index
end

get "/help" do
  erb :help
end

get '/solution' do
  #the user can go to /solution and see the complete solution
  @solution = session[:solution]
  @puzzle = session[:puzzle]
  @current_solution = session[:solution]
  erb :index
end

get '/hard' do
  new_hard_puzzle
  redirect '/'
end

post '/' do
  #this saves the current solution in the session 'Hash' (converting #the array into a string) and sets check_solution to true before #redirecting.
  cells = box_order_to_row_order(params["cell"])
  session[:current_solution] = cells.map {|value| value.to_i }.join
  session[:check_solution] = true
  redirect '/'
end

get '/button' do
 new_puzzle
 redirect '/'
end


