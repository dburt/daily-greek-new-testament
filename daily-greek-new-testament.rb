#!/usr/bin/env ruby
#
# Send some random verses from the Greek New Testament by email
#

require 'rubygems'
require 'mail'
require 'erb'
require 'date'
require 'pathname'

module DailyGreekNewTestament

  BOOKS_IN_ORDER = %w[
    Mt Mk Lk Jn Ac
    Ro 1Co 2Co Ga Eph Php Col 1Th 2Th 1Ti 2Ti Tit Phm
    Heb Jas 1Pe 2Pe 1Jn 2Jn 3Jn Jud Re
  ]

  BOOK_GROUPS = {
    "Luke and Paul" => %w[ Lk Ac Ro 1Co 2Co Ga Eph Php Col 1Th 2Th 1Ti 2Ti Tit Phm ],
    "Matthew and James" => %w[ Mt Heb Jas ],
    "Mark and Peter" => %w[ Mk 1Pe 2Pe Jud ],
    "John" => %w[ Jn 1Jn 2Jn 3Jn Re ],
  }

  SERIAL_VERSE_START = Date.new(2016, 8, 1)
  SERIAL_BOOKS = %w[ 1Jn 2Jn 3Jn Jn Mk ]

  def books
    Book.all
  end

  def verses
    books.map(&:verses).flatten
  end

  def day_number
    Date.today - SERIAL_VERSE_START
  end

  def verses_from_book_names(book_names)
    book_names.inject([]) {|memo, name| memo.concat Book[name].verses }
  end

  def serial_verse_for_today
    verses_from_book_names(SERIAL_BOOKS)[day_number]
  end

  def random_verse_from_books(book_names)
    verses_from_book_names(book_names).sample
  end

  def verses_for_today
    verses = { "Serial" => serial_verse_for_today }
    BOOK_GROUPS.each do |name, books|
      verses[name] = random_verse_from_books(books)
    end
    verses
  end

  def mail_body
    verses = verses_for_today
    ERB.new(File.read("daily-gnt-email.erb")).result(binding)
  end

  def human_date
    # + 1 for Australia from USA
    (Date.today + 1).strftime("%d %b %Y")
  end

  class Book
    attr_reader :path, :number, :short_name

    def initialize(pathname)
      @path = pathname
      @number = pathname.to_s[/\b\d\d/]
      @short_name = pathname.to_s[/\b\d\d-(.*?)-/, 1]
    end

    def words
      path.readlines.map {|line| Word.new(self, line) }
    end

    def verses
      words.group_by {|word| word.passage }.map do |passage, words|
        Verse.new(words)
      end
    end

    def self.[](short_name)
      all.detect {|book| book.short_name == short_name }
    end

    def self.all
      @all ||= Pathname.glob("sblgnt/*-morphgnt.txt").map {|pathname| new(pathname) }
    end
  end

  class Word
    MORPH_LINE_PATTERN = /
      ((\d\d)(\d\d)(\d\d))
      \ (A-|C-|D-|I-|N-|P-|RA|RD|RI|RP|RR|V-|X-)
      \ ((1|2|3|-)(P|I|F|A|X|Y|-)(A|M|P|-)(I|D|S|O|N|P|-)(N|G|D|A|V|-)(S|P|-)(M|F|N|-)(C|S|-))
      \ (\S+)
      \ (\S+)
      \ (\S+)
      \ (\S+)
    /ux

    MORPH_LINE_PATTERN_MATCHES = %w(
      passage
      passage_book
      passage_chapter
      passage_verse
      part_of_speech
      parsing
      parsing_person
      parsing_tense
      parsing_voice
      parsing_mood
      parsing_case
      parsing_number
      parsing_gender
      parsing_degree
      text_incl_punctuation
      word
      normalized_word
      lemma
    )

    MX = MORPH_LINE_PATTERN_MATCHES.each_with_index.inject({}) do |memo, (name, i)|
      memo[name] = i + 1  # 1-based like MatchData
      memo
    end

    attr_reader :book

    def initialize(book, morph_line)
      @book = book
      @match_data = MORPH_LINE_PATTERN.match(morph_line)
    end

    MORPH_LINE_PATTERN_MATCHES.each do |field_name|
      define_method(field_name) do
        @match_data[MX[field_name]]
      end
    end
  end

  class Verse
    attr_accessor :words

    def initialize(words)
      @words = words
    end

    def to_s
      @words.map {|word| word.text_incl_punctuation }.join(" ")
    end

    def passage
      @passage ||= @words.first.passage
    end

    def human_ref
      "#{bk} #{ch}:#{v}"
    end

    def bk
      BOOKS_IN_ORDER[passage[0, 2].to_i - 1]
    end

    def ch
      passage[2, 2].to_i
    end

    def v
      passage[4, 2].to_i
    end
  end

end

if $0 == __FILE__

  Encoding.default_external = 'utf-8'

  include DailyGreekNewTestament

  # puts mail_body
  # exit

  mail = Mail.new do
    from 'dave@burt.id.au'
    to 'ridley-daily-greek-new-testament@googlegroups.com'
    subject "Ridley Daily Greek New Testament " + human_date
    content_type 'text/html; charset=UTF-8'
    body mail_body
  end
  mail.delivery_method :sendmail
  mail.deliver!

end

