public class DailyNewsletterScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new DailyNewsletterBatch(), 1);
    }
}
