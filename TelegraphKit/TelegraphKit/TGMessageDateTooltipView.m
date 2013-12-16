#import "TGMessageDateTooltipView.h"

#import "TGDateLabel.h"

#import "TGDateUtils.h"
#import "TGImageUtils.h"

@interface TGMessageDateTooltipView ()

@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *dayLabel;
@property (nonatomic, strong) TGDateLabel *dateLabel;
@property (nonatomic, strong) UILabel *dayOfMonthLabel;
@property (nonatomic, strong) UILabel *dayOfWeekLabel;

@end

@implementation TGMessageDateTooltipView

@synthesize iconView = _iconView;
@synthesize dayLabel = _dayLabel;
@synthesize dateLabel = _dateLabel;
@synthesize dayOfMonthLabel = _dayOfMonthLabel;
@synthesize dayOfWeekLabel = _dayOfWeekLabel;

- (id)init
{
    UIImage *rawLeftImage = [UIImage imageNamed:@"MessageDateCalloutLeft.png"];
    UIImage *rawRightImage = [UIImage imageNamed:@"MessageDateCalloutRight.png"];
    
    self = [super initWithLeftImage:[rawLeftImage stretchableImageWithLeftCapWidth:(int)(rawLeftImage.size.width - 1) topCapHeight:0] centerImage:[UIImage imageNamed:@"MessageDateCalloutCenter.png"] centerUpImage:[UIImage imageNamed:@"MessageDateCalloutCenter_Up.png"] rightImage:[rawRightImage stretchableImageWithLeftCapWidth:1 topCapHeight:0]];
    if (self != nil)
    {
        _iconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"MessageDateTooltipCalendar.png"]];
        _iconView.frame = CGRectOffset(_iconView.frame, 8, 8);
        [self addSubview:_iconView];
        
        _dayLabel = [[UILabel alloc] init];
        _dayLabel.font = [UIFont boldSystemFontOfSize:12];
        _dayLabel.textColor = UIColorRGBA(0xffffff, 0.6f);
        _dayLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:_dayLabel];
        
        _dateLabel = [[TGDateLabel alloc] initWithFrame:CGRectZero];
        _dateLabel.dateFont = [UIFont systemFontOfSize:12];
        _dateLabel.dateTextFont = _dateLabel.dateFont;
        _dateLabel.dateLabelFont = [UIFont systemFontOfSize:10];
        _dateLabel.amWidth = 17;
        _dateLabel.pmWidth = 17;
        _dateLabel.dstOffset = 1.5f;
        _dateLabel.textColor = UIColorRGBA(0xffffff, 0.6f);
        _dateLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:_dateLabel];
        
        _dayOfMonthLabel = [[UILabel alloc] initWithFrame:CGRectMake(11, 16, 21, 16)];
        _dayOfMonthLabel.font = [UIFont boldSystemFontOfSize:16];
        _dayOfMonthLabel.textAlignment = UITextAlignmentCenter;
        _dayOfMonthLabel.textColor = UIColorRGB(0x111111);
        _dayOfMonthLabel.shadowColor = [UIColor whiteColor];
        _dayOfMonthLabel.shadowOffset = CGSizeMake(0, 1);
        _dayOfMonthLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:_dayOfMonthLabel];
        
        _dayOfWeekLabel = [[UILabel alloc] init];
        _dayOfWeekLabel.font = [UIFont boldSystemFontOfSize:12];
        _dayOfWeekLabel.textColor = [UIColor whiteColor];
        _dayOfWeekLabel.shadowColor = [UIColor blackColor];
        _dayOfWeekLabel.shadowOffset = CGSizeMake(0, -1);
        _dayOfWeekLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:_dayOfWeekLabel];
    }
    return self;
}

- (void)setDate:(int)date
{
    _dateLabel.dateText = [TGDateUtils stringForShortTime:date];
    CGSize dateTextSize = [_dateLabel measureTextSize];
    _dateLabel.frame = CGRectMake(0, 0, dateTextSize.width, dateTextSize.height);
    
    int dayOfMonth = 1;
    _dayLabel.text = [TGDateUtils stringForDayOfMonth:date dayOfMonth:&dayOfMonth];
    [_dayLabel sizeToFit];
    
    _dayOfMonthLabel.text = [[NSString alloc] initWithFormat:@"%d", dayOfMonth];
    
    _dayOfWeekLabel.text = [TGDateUtils stringForDayOfWeek:date];
    [_dayOfWeekLabel sizeToFit];
    
    [self sizeToFit];
}

- (void)sizeToFit
{
    CGAffineTransform transform = self.transform;
    self.transform = CGAffineTransformIdentity;
    
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, MAX(39 + _dayLabel.frame.size.width + 4 + _dateLabel.frame.size.width + 10, self.minLeftWidth + self.minRightWidth + self.centerView.frame.size.width), self.centerView.frame.size.height);
    
    self.transform = transform;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize viewSize = self.bounds.size;
    
    _dayOfWeekLabel.frame = CGRectMake(39, 6, _dayOfWeekLabel.frame.size.width, _dayOfWeekLabel.frame.size.height);
    _dayLabel.frame = CGRectMake(39, 21, _dayLabel.frame.size.width, _dayLabel.frame.size.height);
    _dateLabel.frame = CGRectMake(viewSize.width - 10 - _dateLabel.frame.size.width, 21, _dateLabel.frame.size.width, _dateLabel.frame.size.height);
}

@end
