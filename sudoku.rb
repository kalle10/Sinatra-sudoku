require 'sinatra'
require_relative './lib/sudoku'
require_relative './lib/cell'

enable :sessions

def random_sudoku
    # we're using 9 numbers, 1 to 9, and 72 zeros as an input
    # it's obvious there may be no clashes as all numbers are unique
    seed = (1..9).to_a.shuffle + Array.new(81-9, 0)
    sudoku = Sudoku.new(seed.join)
    # then we solve this (really hard!) sudoku
    sudoku.solve!
    # and give the output to the view as an array of chars
    sudoku.to_s.chars
end

# this method removes some digits from the solution to create a puzzle
def puzzle(sudoku)
  sudoku = random_sudoku
  indices = (1..81).to_a.sample(40)
  indices.each do |index|
  sudoku[index] = ''
  end
  sudoku
end
  

get '/' do
  prepare_to_check_solution
  generate_new_puzzle_if_necessary
  @current_solution = session[:current_solution] || session[:puzzle]
  @solution = session[:solution]
  @puzzle = session[:puzzle]
  erb :index
end

get '/restart' do
	session = nil
	redirect to('/')
end

get '/solution' do
  @solution = session[:solution]
  @puzzle = session[:puzzle]	
  @current_solution = session[:solution]
  erb :index
end

post '/' do
  # the cells in HTML are ordered box by box 
  # (first box1, then box2, etc),
  # so the form data (params['cell']) is sent using this order
  # However, our code expects it to be row by row, 
  # so we need to transform it.
  cells = box_order_to_row_order(params["cell"]) 
  session[:current_solution] = cells.map{|value| value.to_i }.join
  session[:check_solution] = true
  redirect to("/")
end


def box_order_to_row_order(cells)
  # first, we break down 81 cells into 9 arrays of 9 cells, 
  # each representing one box
  boxes = cells.each_slice(9).to_a
  # we're using an array of indexes 0 to 8 purely to help 
  # figure out where to look for the cells.
  # So, here i is the row number that we're "assembling" 
  # from three separate boxes using inject()
  # By this point you need to and you are required 
  # to understand how inject() works
  # http://ruby-doc.org/core-2.0.0/Enumerable.html#method-i-inject
  (0..8).to_a.inject([]) {|memo, i|
    # we're dividing an integer by an integer, it's called 
    # an integer division
    # the result will also be an integer, e.g. 0/3=0, 
    # 1/3=0, 2/3=0, 3/3=1, 4/3=1, etc.
    # Then we multiply it by the numbers of row in a box. 
    # This gives us the index of the first box
    # that contains the digits for index i.
    first_box_index = i / 3 * 3
    # then we take three of them, starting from the first box index.
    # The digits for row i are in these three boxes
    three_boxes = boxes[first_box_index, 3]
    # Now let's extract them. We'll use map() to get 
    # three rows out of three boxes
    three_rows_of_three = three_boxes.map do |box| 
      # The question is which rows do we need?
      # We can calculate them using the variable i, the row number.
      # If we get the remainder of the division of 
      # the number of the row we need and 
      # the number of the rows in a box (3), we'll get 
      # the row number in the box we need
      row_number_in_a_box = i % 3
      # once we know the row number in the box, we get 
      # the cell index by multiplying it by
      # the number of cells in a row
      first_cell_in_the_row_index = row_number_in_a_box * 3
      # and then we take three values starting from that row
      box[first_cell_in_the_row_index, 3]
    end
    # this way we get an array of three rows from the boxes, 
    # three elements each
    # We flatten them into a single array of 9, which gives us a 
    # row number i
    # we add it to the memo, so inject will eventually return us 
    # an array of 81 elements that we need
    memo += three_rows_of_three.flatten
  }
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
  session[:check_solution] = nil
end

helpers do

  def cell_value(value)
    value.to_i == 0 ? '' : value
  end    

  def colour_class(solution_to_check, puzzle_value, current_solution_value, solution_value)
    must_be_guessed = puzzle_value == 0
	tried_to_guess = current_solution_value.to_i != 0
    guessed_incorrectly = current_solution_value != solution_value

    if solution_to_check && 
        must_be_guessed && 
        tried_to_guess && 
        guessed_incorrectly
      'incorrect'
    elsif !must_be_guessed
      'value-provided'
    end
  end
end

