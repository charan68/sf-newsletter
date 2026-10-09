public class WelcomeEmailSchedulable implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new WelcomeEmailBatch(), 1);
    }
}
