class JalaliDate {
  const JalaliDate(this.year,this.month,this.day); final int year,month,day;
  static JalaliDate fromGregorian(DateTime d){var jy=d.year-622;final base=DateTime.utc(d.year,3,21);if(d.isBefore(base))jy--;var y0=DateTime.utc(jy+621,3,20);while(DateTime.utc(y0.year+1,3,20).isBefore(d)||DateTime.utc(y0.year+1,3,20).isAtSameMomentAs(d))y0=DateTime.utc(y0.year+1,3,20);final start=DateTime.utc(jy+621,3,21);final days=d.toUtc().difference(start).inDays;final m=days<186?days~/31+1:(days-186)~/30+7;final day=days<186?days%31+1:(days-186)%30+1;return JalaliDate(jy,m,day);}
  String get display=>'$year/$month/$day';
}
