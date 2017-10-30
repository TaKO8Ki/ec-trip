class Item < ApplicationRecord
  belongs_to :category
  belongs_to :caption_image, class_name: 'Image'
  has_many :purchase_details
  has_many :favorites

  enum status: {unpublished: 0, selling: 1, end_of_sell: 2}

  before_validation :set_tinymce_images_path

  validates :name, presence: true
  validates :stock_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :price, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_nil: true

  validates :description, presence: true, if: :published?
  validates :about, presence: true, if: :published?
  validates :stock_quantity, presence: true, if: :published?
  validates :price, presence: true, if: :published?
  validate :change_to_unpublished

  scope :published, -> { where(status: [:selling, :end_of_sell]) }
  scope :selling, -> { where(status: :selling) }

  attr_accessor :preview

  def save
    # 販売終了時は在庫をゼロにする
    self.stock_quantity = 0 if self.end_of_sell?
    super
  end

  def price_include_tax
    Util.calc_tax_included(self.price)
  end

  def caption_image_url
    if self.caption_image
      self.caption_image.public_url(:caption)
    else
      'no_img.jpg'
    end
  end

  def can_sell?
    self.selling? && self.stock_quantity > 0
  end

  private
  def set_tinymce_images_path
    # Tinymceのバグ？で、localに画像を保存すると相対パスに変換されてしまうため、
    # それを絶対パスに置換する
    if Rails.env.development? && self.about
      loop do
        break unless self.about.gsub!('src="../', 'src="')
      end
      self.about.gsub!('src="assets', 'src="/assets')
    end
  end

  def change_to_unpublished
    # 公開後から非公開への変更は不可
    if self.status_was != 'unpublished' && self.unpublished?
      self.errors.add(:status, 'は公開後に未公開へ戻すことはできません')
    end
  end

  def published?
    self.selling? || self.end_of_sell? || self.preview
  end

end
