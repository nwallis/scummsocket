defmodule ScummIndex do

  defguard common_block_type(value) when value === "0R" or value === "0S" or value === "0N" or value === "0C"

  def parse do
    File.open!("assets/000.lfl")
    |> find_a_block
  end

  #performs recursive block parsing until :eof is hit
  def find_a_block(assets_file_pointer) do
    block_meta_data = get_block_meta_data(assets_file_pointer)
    parse_block(block_meta_data, assets_file_pointer)
    find_a_block(assets_file_pointer)
  end

  defp get_block_meta_data(assets_file_pointer) do
    block_size = Helpers.binread_reverse_decode(assets_file_pointer,4)
    block_type = IO.binread(assets_file_pointer,2)
    {block_size, block_type}
  end

  def parse_block( {block_size, "RN"} , assets_file_pointer) do

    # block data includes block size of 4 bytes, block type of 2 bytes and trailing null byte
    # so 7 bytes in total, each room is 10 bytes in size.  This does not currently account fo
    # a corrupt disk image

    number_of_rooms = trunc( (block_size - 7) / 10 )

    room_data = Enum.reduce(1..number_of_rooms, %{}, fn(_, acc) ->

      room_number = Helpers.binread_decode(assets_file_pointer,1)

      room_name = assets_file_pointer
      |> IO.binread(9)
      |> Helpers.xor(0xFF)

      Map.put(acc, room_name, room_number)
      Map.put(acc, room_number, room_name)

    end)

    # discard end of block null byte
    :file.position(assets_file_pointer, block_size)

    %{"rooms" => room_data}

  end

  def parse_block( { _, block_type} , assets_file_pointer) when common_block_type(block_type) do

    number_of_items = Helpers.binread_reverse_decode(assets_file_pointer,2)

    block_data = Enum.reduce(1..number_of_items, %{}, fn(_, acc) ->

      file_number = Helpers.binread_reverse_decode(assets_file_pointer,1)
      offset = Helpers.binread_reverse_decode(assets_file_pointer,4)
      Map.put(acc, file_number, offset)

    end)

    %{"scripts_data" => block_data}

  end

  def parse_block( {_, "0O"} , assets_file_pointer) do

    number_of_items = Helpers.binread_reverse_decode(assets_file_pointer,2)

    block_data = Enum.reduce(1..number_of_items, %{}, fn(_, acc) ->

      class_data = Helpers.binread_decode(assets_file_pointer,3)
      owner_state = Helpers.binread_decode(assets_file_pointer,1)

      #extract the 4 bits for state and owner
      owner = owner_state
      |> Bitwise.band(0xF0)
      |> Bitwise.>>>(4)

      state = Bitwise.band(owner_state, 0x0F)

      Map.put(acc, class_data, %{owner: owner, state: state})

    end)

    %{"room_directory" => block_data}

  end

end
